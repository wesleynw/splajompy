package service

import (
	"context"
	"math"
	"regexp"
	"slices"
	"sort"
	"strings"
	"time"

	"github.com/bbalet/stopwords"
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"
)

type WrappedService struct {
	querier     queries.Querier
	postService PostService
}

func NewWrappedService(querier queries.Querier, postService PostService) *WrappedService {
	return &WrappedService{
		querier:     querier,
		postService: postService,
	}
}

var fetchLimit = 50

type WrappedData struct {
	ActivityData                  UserActivityData              `json:"activityData"`
	WeeklyActivity                []int                         `json:"weeklyActivityData"` // not my best piece of programming, but just assume this is len=7
	SliceData                     SliceData                     `json:"sliceData"`
	ComparativePostStatisticsData ComparativePostStatisticsData `json:"comparativePostStatisticsData"`
	MostLikedPost                 *models.DetailedPost          `json:"mostLikedPost"`
	FavoriteUsers                 []FavoriteUserData            `json:"favoriteUsers"`
	ControversialPoll             *models.DetailedPoll          `json:"controversialPoll"`
	TopTopics                     []TopicData                   `json:"topTopics"`
}

type SliceData struct {
	Percent          float32 `json:"percent"`
	PostComponent    float32 `json:"postComponent"`
	CommentComponent float32 `json:"commentComponent"`
	LikeComponent    float32 `json:"likeComponent"`
}

type UserActivityData struct {
	ActivityCountCeiling int            `json:"activityCountCeiling"`
	Counts               map[string]int `json:"counts"`
	MostActiveDay        string         `json:"mostActiveDay"`
}

type ComparativePostStatisticsData struct {
	PostLengthVariation  float32 `json:"postLengthVariation"`
	ImageLengthVariation float32 `json:"imageLengthVariation"`
}

type FavoriteUserData struct {
	User       models.PublicUser `json:"user"`
	Proportion float64           `json:"proportion"`
}

type TopicData struct {
	Word       string  `json:"word"`
	TfIdfScore float64 `json:"tfIdfScore"`
}

func (s *WrappedService) CompileWrappedForUser(ctx context.Context, userId int) (*WrappedData, error) {
	var data WrappedData

	activity, weeklyActivity, err := s.getUserActivityData(ctx, userId)
	if err != nil {
		return nil, err
	}
	data.ActivityData = *activity
	data.WeeklyActivity = *weeklyActivity

	sliceData, err := s.getPercentShareOfContent(ctx, userId)
	if err != nil {
		return nil, err
	}
	data.SliceData = *sliceData

	comparativePostData, err := s.getComparativePostData(ctx, userId)
	if err != nil {
		return nil, err
	}
	data.ComparativePostStatisticsData = *comparativePostData

	mostLikedPost, err := s.getMostLikedPost(ctx, userId)
	if err != nil {
		return nil, err
	}
	data.MostLikedPost = mostLikedPost

	favoriteUsers, err := s.getFavoriteUsers(ctx, userId)
	if err != nil {
		return nil, err
	}
	data.FavoriteUsers = *favoriteUsers

	poll, err := s.getControversialPoll(ctx, userId)
	if err != nil {
		return nil, err
	}
	data.ControversialPoll = poll

	topTopics, err := s.getTopTopics(ctx, userId)
	if err != nil {
		return nil, err
	}
	data.TopTopics = topTopics

	return &data, nil
}

func (s *WrappedService) getUserActivityData(ctx context.Context, userId int) (*UserActivityData, *[]int, error) {
	counts := make(map[string]int)
	weeklyCounts := make([]int, 7)
	yearStart := time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)
	yearEnd := time.Date(2025, 12, 31, 23, 59, 0, 0, time.UTC)

	for d := yearStart; !d.After(yearEnd); d = d.AddDate(0, 0, 1) {
		counts[d.Format("2006-01-02")] = 0
	}

	var cursor *time.Time
	ceiling := 0
	mostActiveDay := ""

	// posts
	for {
		var timestamp pgtype.Timestamp
		if cursor != nil {
			timestamp.Time = *cursor
			timestamp.Valid = true
		}

		posts, err := s.querier.WrappedGetAllUserPostsWithCursor(ctx, queries.WrappedGetAllUserPostsWithCursorParams{
			UserID: userId,
			Limit:  fetchLimit,
			Cursor: timestamp,
		})
		if err != nil {
			return nil, nil, err
		}
		if len(posts) == 0 {
			break
		}

		var lastPost *queries.Post
		for _, post := range posts {
			if post.CreatedAt.Time.Year() == 2025 {
				dateKey := post.CreatedAt.Time.Format("2006-01-02")
				counts[dateKey]++
				if counts[dateKey] > ceiling {
					ceiling = counts[dateKey]
					mostActiveDay = dateKey
				}

				weeklyCounts[post.CreatedAt.Time.Weekday()]++
			}
			lastPost = &post
		}
		cursor = &lastPost.CreatedAt.Time
	}

	cursor = nil

	// comments
	for {
		var timestamp pgtype.Timestamp
		if cursor != nil {
			timestamp.Time = *cursor
			timestamp.Valid = true
		}

		comments, err := s.querier.WrappedGetAllUserCommentsWithCursor(ctx, queries.WrappedGetAllUserCommentsWithCursorParams{
			UserID: userId,
			Limit:  fetchLimit,
			Cursor: timestamp,
		})
		if err != nil {
			return nil, nil, err
		}
		if len(comments) == 0 {
			break
		}

		var lastComment *queries.Comment
		for _, comment := range comments {
			if comment.CreatedAt.Time.Year() == 2025 {
				dateKey := comment.CreatedAt.Time.Format("2006-01-02")
				counts[dateKey]++
				if counts[dateKey] > ceiling {
					ceiling = counts[dateKey]
					mostActiveDay = dateKey
				}

				weeklyCounts[comment.CreatedAt.Time.Weekday()]++
			}
			lastComment = &comment
		}
		cursor = &lastComment.CreatedAt.Time
	}

	cursor = nil

	// likes
	for {
		var timestamp pgtype.Timestamptz
		if cursor != nil {
			timestamp.Time = *cursor
			timestamp.Valid = true
		}

		likes, err := s.querier.WrappedGetAllUserLikesWithCursor(ctx, queries.WrappedGetAllUserLikesWithCursorParams{
			UserID: userId,
			Limit:  fetchLimit,
			Cursor: timestamp,
		})
		if err != nil {
			return nil, nil, err
		}
		if len(likes) == 0 {
			break
		}

		var lastLike *queries.Like
		for _, like := range likes {
			if like.CreatedAt.Time.Year() == 2025 {
				dateKey := like.CreatedAt.Time.Format("2006-01-02")
				counts[dateKey]++
				if counts[dateKey] > ceiling {
					ceiling = counts[dateKey]
					mostActiveDay = dateKey
				}

				weeklyCounts[like.CreatedAt.Time.Weekday()]++
			}
			lastLike = &like
		}
		cursor = &lastLike.CreatedAt.Time
	}

	// scale weekly activity to 100
	scale := slices.Max(weeklyCounts)
	for index := range len(weeklyCounts) {
		computed := (100 * weeklyCounts[index]) / scale
		weeklyCounts[index] = computed
	}

	return &UserActivityData{
		ActivityCountCeiling: ceiling,
		Counts:               counts,
		MostActiveDay:        mostActiveDay,
	}, &weeklyCounts, nil
}

func (s *WrappedService) getPercentShareOfContent(ctx context.Context, userId int) (*SliceData, error) {
	totalPosts, err := s.querier.GetTotalPosts(ctx)
	if err != nil {
		return nil, err
	}

	totalComments, err := s.querier.GetTotalComments(ctx)
	if err != nil {
		return nil, err
	}

	totalLikes, err := s.querier.GetTotalLikes(ctx)
	if err != nil {
		return nil, err
	}

	userPosts, err := s.querier.GetTotalPostsForUser(ctx, userId)
	if err != nil {
		return nil, err
	}

	userComments, err := s.querier.GetTotalCommentsForUser(ctx, userId)
	if err != nil {
		return nil, err
	}

	userLikes, err := s.querier.GetTotalLikesForUser(ctx, userId)
	if err != nil {
		return nil, err
	}

	const postWeight = 1
	const commentWeight = 0.2
	const likeWeight = 0.05

	totalWeight := float32(totalPosts)*postWeight + float32(totalComments)*commentWeight + float32(totalLikes)*likeWeight
	userWeight := float32(userPosts)*postWeight + float32(userComments)*commentWeight + float32(userLikes)*likeWeight

	userPostWeight := float32(userPosts) * postWeight
	userCommentWeight := float32(userComments) * commentWeight
	userLikeWeight := float32(userLikes) * likeWeight

	percent := (userWeight / totalWeight) * 100
	postComponent := (userPostWeight / totalWeight) * 100
	commentComponent := (userCommentWeight / totalWeight) * 100
	likeComponent := (userLikeWeight / totalWeight) * 100

	return &SliceData{
		Percent:          percent,
		PostComponent:    postComponent,
		CommentComponent: commentComponent,
		LikeComponent:    likeComponent,
	}, nil
}

func (s *WrappedService) getComparativePostData(ctx context.Context, userId int) (*ComparativePostStatisticsData, error) {
	averagePostLength, err := s.querier.WrappedGetAveragePostLength(ctx)
	if err != nil {
		return nil, err
	}

	userAveragePostLength, err := s.querier.WrappedGetAveragePostLengthForUser(ctx, userId)
	if err != nil {
		return nil, err
	}

	averageImageCount, err := s.querier.WrappedGetAverageImageCountPerPost(ctx)
	if err != nil {
		return nil, err
	}

	userAverageImageCount, err := s.querier.WrappedGetAverageImageCountPerPostForUser(ctx, userId)
	if err != nil {
		return nil, err
	}

	data := ComparativePostStatisticsData{
		PostLengthVariation:  float32(userAveragePostLength) - float32(averagePostLength),
		ImageLengthVariation: float32(averageImageCount) - float32(userAverageImageCount),
	}

	return &data, nil
}

func (s *WrappedService) getMostLikedPost(ctx context.Context, userId int) (*models.DetailedPost, error) {
	postId, err := s.querier.WrappedGetMostLikedPostId(ctx, userId)
	if err != nil {
		return nil, err
	}

	post, err := s.postService.GetPostById(ctx, userId, postId.PostID)
	if err != nil {
		return nil, err
	}

	return post, nil
}

func (s *WrappedService) getFavoriteUsers(ctx context.Context, userId int) (*[]FavoriteUserData, error) {
	givenPostLikes, err := s.querier.WrappedGetUsersWhoGetMostLikesForPosts(ctx, userId)
	if err != nil {
		return nil, err
	}

	givenCommentLikes, err := s.querier.WrappedGetUsersWhoGetMostLikesForComments(ctx, userId)
	if err != nil {
		return nil, err
	}

	givenComments, err := s.querier.WrappedGetUsersWhoGetMostComments(ctx, userId)
	if err != nil {
		return nil, err
	}

	weights := make(map[int]float64)

	for _, row := range givenPostLikes {
		postCount, err := s.querier.WrappedGetPostCountForUser(ctx, row.UserID)
		if err != nil {
			return nil, err
		}

		weights[row.UserID] += float64(row.LikeCount) / max(float64(postCount), 1)
	}

	for _, row := range givenCommentLikes {
		commentCount, err := s.querier.WrappedGetCommentCountForUser(ctx, row.UserID)
		if err != nil {
			return nil, err
		}

		weights[row.UserID] += float64(row.LikeCount) / max(float64(commentCount), 1)
	}

	for _, row := range givenComments {
		weights[row.UserID] += float64(row.CommentCount) * 3
	}

	type userWeight struct {
		UserID int
		Weight float64
	}

	sorted := make([]userWeight, 0, len(weights))
	var maxWeight float64
	for userID, weight := range weights {
		sorted = append(sorted, userWeight{UserID: userID, Weight: weight})
		if weight > maxWeight {
			maxWeight = weight
		}
	}

	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].Weight > sorted[j].Weight
	})

	limit := min(5, len(sorted))

	users := make([]FavoriteUserData, 0, limit)
	for _, uw := range sorted[:limit] {
		user, err := s.querier.GetUserById(ctx, uw.UserID)
		if err != nil {
			continue
		}

		scaledWeight := float64(0)
		if maxWeight > 0 {
			scaledWeight = (uw.Weight / maxWeight) * 100
		}

		users = append(users, FavoriteUserData{
			User:       utilities.MapUserToPublicUser(user),
			Proportion: scaledWeight,
		})
	}

	return &users, nil
}

func (s *WrappedService) getControversialPoll(ctx context.Context, userId int) (*models.DetailedPoll, error) {
	polls, err := s.querier.WrappedGetPollsThatUserVotedIn(ctx, userId)
	if err != nil {
		return nil, err
	}

	minProportion := 100
	var poll *models.DetailedPoll

	for index := range len(polls) {
		pollDetails, err := s.postService.GetPollDetails(ctx, userId, polls[index].PostID, polls[index].Attributes.Poll)
		if err != nil {
			return nil, err
		}

		userVotePercentage := pollDetails.Options[*pollDetails.CurrentUserVote].VoteTotal / pollDetails.VoteTotal
		if userVotePercentage < minProportion {
			minProportion = userVotePercentage
			poll = pollDetails
		}
	}

	return poll, nil
}

func (s *WrappedService) getTopTopics(ctx context.Context, userId int) ([]TopicData, error) {
	var documents [][]string
	var cursor *time.Time

	// Fetch and tokenize all user posts
	for {
		var timestamp pgtype.Timestamp
		if cursor != nil {
			timestamp.Time = *cursor
			timestamp.Valid = true
		}

		posts, err := s.querier.WrappedGetAllUserPostsWithCursor(ctx, queries.WrappedGetAllUserPostsWithCursorParams{
			UserID: userId,
			Limit:  fetchLimit,
			Cursor: timestamp,
		})
		if err != nil {
			return nil, err
		}
		if len(posts) == 0 {
			break
		}

		var lastPost *queries.Post
		for _, post := range posts {
			if post.CreatedAt.Time.Year() == 2025 && post.Text.Valid {
				tokens := tokenizeText(post.Text.String, post.Facets)
				if len(tokens) > 0 {
					documents = append(documents, tokens)
				}
			}
			lastPost = &post
		}
		cursor = &lastPost.CreatedAt.Time
	}

	cursor = nil

	// Fetch and tokenize all user comments
	for {
		var timestamp pgtype.Timestamp
		if cursor != nil {
			timestamp.Time = *cursor
			timestamp.Valid = true
		}

		comments, err := s.querier.WrappedGetAllUserCommentsWithCursor(ctx, queries.WrappedGetAllUserCommentsWithCursorParams{
			UserID: userId,
			Limit:  fetchLimit,
			Cursor: timestamp,
		})
		if err != nil {
			return nil, err
		}
		if len(comments) == 0 {
			break
		}

		var lastComment *queries.Comment
		for _, comment := range comments {
			if comment.CreatedAt.Time.Year() == 2025 {
				tokens := tokenizeText(comment.Text, comment.Facets)
				if len(tokens) > 0 {
					documents = append(documents, tokens)
				}
			}
			lastComment = &comment
		}
		cursor = &lastComment.CreatedAt.Time
	}

	// Calculate TF-IDF and return top 10 topics
	return calculateTfIdf(documents, 10), nil
}

// tokenizeText takes a text string, facets, cleans it, and returns a slice of words without stopwords
func tokenizeText(text string, facets db.Facets) []string {
	// Remove faceted content (tags, mentions, etc.) by replacing with spaces
	// Sort facets by index in reverse order to avoid index shifting
	sortedFacets := make([]db.Facet, len(facets))
	copy(sortedFacets, facets)
	sort.Slice(sortedFacets, func(i, j int) bool {
		return sortedFacets[i].IndexStart > sortedFacets[j].IndexStart
	})

	// Convert text to rune slice for proper unicode handling
	runes := []rune(text)
	for _, facet := range sortedFacets {
		if facet.IndexStart >= 0 && facet.IndexEnd <= len(runes) {
			// Replace faceted content with spaces
			for i := facet.IndexStart; i < facet.IndexEnd; i++ {
				runes[i] = ' '
			}
		}
	}
	text = string(runes)

	// Remove {tag: ...} syntax
	tagRegex := regexp.MustCompile(`\{tag:\s*[^}]*\}`)
	text = tagRegex.ReplaceAllString(text, "")

	// Remove URLs
	urlRegex := regexp.MustCompile(`https?://[^\s]+`)
	text = urlRegex.ReplaceAllString(text, "")

	// Clean the text using stopwords library (removes stopwords and cleans)
	cleanedText := stopwords.CleanString(text, "en", false)

	// Remove special characters, keep only letters and spaces
	wordRegex := regexp.MustCompile(`[^a-z\s]`)
	cleanedText = wordRegex.ReplaceAllString(strings.ToLower(cleanedText), " ")

	// Split into words
	words := strings.Fields(cleanedText)

	// Filter out very short words (1-2 chars)
	var filteredWords []string
	for _, word := range words {
		if len(word) > 2 {
			filteredWords = append(filteredWords, word)
		}
	}

	return filteredWords
}

// calculateTfIdf computes TF-IDF scores for words across documents
func calculateTfIdf(documents [][]string, topN int) []TopicData {
	if len(documents) == 0 {
		return []TopicData{}
	}

	// Calculate term frequency for each document
	documentTermFrequencies := make([]map[string]int, len(documents))
	for i, doc := range documents {
		tf := make(map[string]int)
		for _, word := range doc {
			tf[word]++
		}
		documentTermFrequencies[i] = tf
	}

	// Calculate document frequency (how many documents contain each term)
	documentFrequency := make(map[string]int)
	for _, tf := range documentTermFrequencies {
		for word := range tf {
			documentFrequency[word]++
		}
	}

	// Calculate TF-IDF scores by summing across all documents
	tfidfScores := make(map[string]float64)
	totalDocs := float64(len(documents))

	for docIndex, tf := range documentTermFrequencies {
		docLength := float64(len(documents[docIndex]))
		if docLength == 0 {
			continue
		}

		for word, count := range tf {
			// TF: normalized term frequency
			termFreq := float64(count) / docLength

			// IDF: inverse document frequency
			idf := math.Log(totalDocs / float64(documentFrequency[word]))

			// Accumulate TF-IDF score
			tfidfScores[word] += termFreq * idf
		}
	}

	// Convert to slice and sort by score
	var results []TopicData
	for word, score := range tfidfScores {
		results = append(results, TopicData{
			Word:       word,
			TfIdfScore: score,
		})
	}

	sort.Slice(results, func(i, j int) bool {
		return results[i].TfIdfScore > results[j].TfIdfScore
	})

	// Return top N
	limit := min(topN, len(results))
	return results[:limit]
}
