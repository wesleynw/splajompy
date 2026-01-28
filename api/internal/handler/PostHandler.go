package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/service"

	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"
)

func (h *Handler) CreateNewPostV2(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

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

	err := h.postService.NewPost(r.Context(), *currentUser, requestBody.Text, requestBody.ImageKeymap, requestBody.Poll, requestBody.Visibility)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) GetPresignedUrl(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	extension := r.URL.Query().Get("extension")
	if extension == "" {
		utilities.HandleError(w, http.StatusBadRequest, "Bad request format")
		return
	}

	folder := r.URL.Query().Get("folder")

	key, url, err := h.postService.NewPresignedStagingUrl(r.Context(), *currentUser, &extension, &folder)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, map[string]string{"key": key, "url": url})
}

func (h *Handler) GetPostById(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	post, err := h.postService.GetPostById(r.Context(), currentUser.UserID, id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, post)
}

func (h *Handler) DeletePostById(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	err = h.postService.DeletePost(r.Context(), *currentUser, id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// Deprecated: in factor of parseTimeBasedPagination
func (h *Handler) parsePagination(r *http.Request) (int, int) {
	limit, offset := 10, 0
	if l, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && l > 0 {
		limit = l
	}
	if o, err := strconv.Atoi(r.URL.Query().Get("offset")); err == nil && o >= 0 {
		offset = o
	}
	return limit, offset
}

func (h *Handler) parseTimeBasedPagination(r *http.Request) (int, *time.Time, error) {
	limit := 10
	if l, err := strconv.Atoi(r.URL.Query().Get("limit")); err == nil && l > 0 {
		limit = l
	}

	var beforeTimestamp *time.Time
	beforeStr := r.URL.Query().Get("before")
	if beforeStr != "" {
		timestamp, err := time.Parse(time.RFC3339, beforeStr)
		if err != nil {
			return 0, nil, errors.New("invalid timestamp format, expected RFC3339")
		}
		beforeTimestamp = &timestamp
	}

	return limit, beforeTimestamp, nil
}

func (h *Handler) GetPostsByUserId(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	limit, offset := h.parsePagination(r)
	posts, err := h.postService.GetPostsByUserId(r.Context(), *currentUser, id, limit, offset)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, posts)
}

// Deprecated: use GetAllPostsWithTimeOffset
func (h *Handler) GetAllPosts(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	limit, offset := h.parsePagination(r)
	posts, err := h.postService.GetAllPosts(r.Context(), *currentUser, limit, offset)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, posts)
}

func (h *Handler) GetPostsByFollowing(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	limit, offset := h.parsePagination(r)
	posts, err := h.postService.GetPostsByFollowing(r.Context(), *currentUser, limit, offset)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	if posts == nil {
		posts = []models.DetailedPost{}
	}
	utilities.HandleSuccess(w, posts)
}

func (h *Handler) GetMutualFeed(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	limit, offset := h.parsePagination(r)
	posts, err := h.postService.GetMutualFeed(r.Context(), *currentUser, limit, offset)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	if posts == nil {
		posts = []models.DetailedPost{}
	}
	utilities.HandleSuccess(w, posts)
}

func (h *Handler) GetPostsByUserIdWithTimeOffset(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	userId, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	limit, beforeTimestamp, err := h.parseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, err.Error())
		return
	}

	posts, err := h.postService.GetPosts(r.Context(), *currentUser, service.FeedTypeProfile, &userId, limit, beforeTimestamp)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, posts)
}

func (h *Handler) AddPostLike(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	err = h.postService.AddLikeToPost(r.Context(), *currentUser, id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// RemovePostLike DELETE /post/{id}/liked endpoint
func (h *Handler) RemovePostLike(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	err = h.postService.RemoveLikeFromPost(r.Context(), *currentUser, id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// ReportPost POST /post/{id}/report
func (h *Handler) ReportPost(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	err = h.postService.ReportPost(r.Context(), currentUser, id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) VoteOnPost(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	postId, err := h.GetIntPathParam(r, "post_id")
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	optionIndex, err := h.GetIntPathParam(r, "option_index")
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	err = h.postService.VoteOnPoll(r.Context(), *currentUser, postId, optionIndex)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) GetAllPostsWithTimeOffset(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	limit, beforeTimestamp, err := h.parseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, err.Error())
		return
	}

	posts, err := h.postService.GetPosts(r.Context(), *currentUser, service.FeedTypeAll, nil, limit, beforeTimestamp)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, posts)
}

func (h *Handler) GetPostsByFollowingWithTimeOffset(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	limit, beforeTimestamp, err := h.parseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, err.Error())
		return
	}

	posts, err := h.postService.GetPosts(r.Context(), *currentUser, service.FeedTypeFollowing, nil, limit, beforeTimestamp)
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
	currentUser := h.getAuthenticatedUser(r)

	limit, beforeTimestamp, err := h.parseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, err.Error())
		return
	}

	posts, err := h.postService.GetPosts(r.Context(), *currentUser, service.FeedTypeMutual, nil, limit, beforeTimestamp)
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
	currentUser := h.getAuthenticatedUser(r)

	postId, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid post ID")
		return
	}

	err = h.postService.PinPost(r.Context(), *currentUser, postId)
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
	currentUser := h.getAuthenticatedUser(r)

	err := h.postService.UnpinPost(r.Context(), *currentUser)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}
