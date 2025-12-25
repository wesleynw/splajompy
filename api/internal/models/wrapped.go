package models

import "time"

type WrappedData struct {
	ActivityData                  UserActivityData              `json:"activityData"`
	WeeklyActivity                []int                         `json:"weeklyActivityData"` // not my best piece of programming, but just assume this is len=7
	SliceData                     SliceData                     `json:"sliceData"`
	ComparativePostStatisticsData ComparativePostStatisticsData `json:"comparativePostStatisticsData"`
	MostLikedPost                 *DetailedPost                 `json:"mostLikedPost"`
	FavoriteUsers                 []FavoriteUserData            `json:"favoriteUsers"`
	ControversialPoll             *DetailedPoll                 `json:"controversialPoll"`
	TotalWordCount                *int                          `json:"totalWordCount"`
	GeneratedUtc                  time.Time                     `json:"generatedUtc"`
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
	User       PublicUser `json:"user"`
	Proportion float64    `json:"proportion"`
}
