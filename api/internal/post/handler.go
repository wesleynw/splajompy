package post

import (
	"encoding/json"
	"net/http"

	"splajompy.com/api/v2/internal/db"

	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) RegisterRoutes(_, withAuth func(string, func(http.ResponseWriter, *http.Request))) {
	// post routes with time-based offset
	withAuth("GET /v2/posts/following", h.GetPostsByFollowingWithTimeOffset)
	withAuth("GET /v2/posts/all", h.GetAllPostsWithTimeOffset)
	withAuth("GET /v2/posts/mutual", h.GetMutualFeedWithTimeOffset)
	withAuth("GET /v2/user/{id}/posts", h.GetPostsByUserIdWithTimeOffset)

	// posts
	withAuth("GET /post/presignedUrl", h.GetPresignedUrl)
	withAuth("POST /v2/post/new", h.CreateNewPostV2)
	withAuth("GET /post/{id}", h.GetPostById)
	withAuth("DELETE /post/{id}", h.DeletePostById)
	withAuth("POST /post/{id}/report", h.ReportPost)

	// polls
	withAuth("POST /post/{post_id}/vote/{option_index}", h.VoteOnPost)

	// likes
	withAuth("POST /post/{id}/liked", h.AddPostLike)
	withAuth("DELETE /post/{id}/liked", h.RemovePostLike)

	// pinning
	withAuth("POST /posts/{id}/pin", h.PinPost)
	withAuth("DELETE /posts/pin", h.UnpinPost)
}

func (h *Handler) CreateNewPostV2(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	var requestBody struct {
		Text        string                   `json:"text"`
		ImageKeymap map[int]models.ImageData `json:"imageKeymap"`
		Visibility  *int                     `json:"visibility"`
		Poll        *db.Poll                 `json:"poll"`
	}

	if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Bad request format")
		return
	}

	if len(requestBody.Text) > 2500 {
		utilities.HandleError(w, http.StatusBadRequest, "Post text exceeds maximum length of 2500 characters")
		return
	}

	_, err := h.svc.NewPost(r.Context(), *currentUser, requestBody.Text, requestBody.ImageKeymap, requestBody.Poll, requestBody.Visibility)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) GetPresignedUrl(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	extension := r.URL.Query().Get("extension")
	if extension == "" {
		utilities.HandleError(w, http.StatusBadRequest, "Bad request format")
		return
	}

	folder := r.URL.Query().Get("folder")

	key, url, err := h.svc.NewPresignedStagingUrl(r.Context(), *currentUser, &extension, &folder)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, map[string]string{"key": key, "url": url})
}

func (h *Handler) GetPostById(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	id, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	post, err := h.svc.GetPostById(r.Context(), currentUser.UserID, id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, post)
}

func (h *Handler) DeletePostById(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	id, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	err = h.svc.DeletePost(r.Context(), *currentUser, id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) GetPostsByUserIdWithTimeOffset(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	userId, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	limit, beforeTimestamp, err := utilities.ParseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, err.Error())
		return
	}

	posts, err := h.svc.GetPosts(r.Context(), *currentUser, FeedTypeProfile, &userId, limit, beforeTimestamp)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, posts)
}

func (h *Handler) AddPostLike(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	id, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	err = h.svc.AddLikeToPost(r.Context(), *currentUser, id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// RemovePostLike DELETE /post/{id}/liked endpoint
func (h *Handler) RemovePostLike(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	id, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	err = h.svc.RemoveLikeFromPost(r.Context(), *currentUser, id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// ReportPost POST /post/{id}/report
func (h *Handler) ReportPost(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	id, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	err = h.svc.ReportPost(r.Context(), currentUser, id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) VoteOnPost(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	postId, err := utilities.GetIntPathParam(r, "post_id")
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	optionIndex, err := utilities.GetIntPathParam(r, "option_index")
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	err = h.svc.VoteOnPoll(r.Context(), *currentUser, postId, optionIndex)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) GetAllPostsWithTimeOffset(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	limit, beforeTimestamp, err := utilities.ParseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, err.Error())
		return
	}

	posts, err := h.svc.GetPosts(r.Context(), *currentUser, FeedTypeAll, nil, limit, beforeTimestamp)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, posts)
}

func (h *Handler) GetPostsByFollowingWithTimeOffset(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	limit, beforeTimestamp, err := utilities.ParseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, err.Error())
		return
	}

	posts, err := h.svc.GetPosts(r.Context(), *currentUser, FeedTypeFollowing, nil, limit, beforeTimestamp)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	if posts == nil {
		posts = []models.DetailedPost{}
	}
	utilities.HandleSuccess(w, posts)
}

func (h *Handler) GetMutualFeedWithTimeOffset(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	limit, beforeTimestamp, err := utilities.ParseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, err.Error())
		return
	}

	posts, err := h.svc.GetPosts(r.Context(), *currentUser, FeedTypeMutual, nil, limit, beforeTimestamp)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	if posts == nil {
		posts = []models.DetailedPost{}
	}
	utilities.HandleSuccess(w, posts)
}

// PinPost POST /posts/{id}/pin
func (h *Handler) PinPost(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	postId, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid post ID")
		return
	}

	err = h.svc.PinPost(r.Context(), *currentUser, postId)
	if err != nil {
		if err.Error() == "post not found" {
			utilities.HandleError(w, http.StatusNotFound, "Post not found")
			return
		}
		if err.Error() == "can only pin your own posts" {
			utilities.HandleError(w, http.StatusForbidden, "You can only pin your own posts")
			return
		}
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// UnpinPost DELETE /posts/pin
func (h *Handler) UnpinPost(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	err := h.svc.UnpinPost(r.Context(), *currentUser)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}
