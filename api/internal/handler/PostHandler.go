package handler

import (
	"encoding/json"
	"net/http"
	"splajompy.com/api/v2/internal/db"
	"strconv"

	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"
)

func (h *Handler) CreateNewPost(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	var requestBody struct {
		Text        string         `json:"text"`
		ImageKeymap map[int]string `json:"imageKeymap"`
	}

	if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Bad request format")
		return
	}

	// Convert old string format to service ImageData with default dimensions
	serviceImageKeymap := make(map[int]models.ImageData)
	for displayOrder, s3Key := range requestBody.ImageKeymap {
		serviceImageKeymap[displayOrder] = models.ImageData{
			S3Key:  s3Key,
			Width:  500,
			Height: 500,
		}
	}

	err := h.postService.NewPost(r.Context(), *currentUser, requestBody.Text, serviceImageKeymap, nil)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) CreateNewPostV2(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	var requestBody struct {
		Text        string                   `json:"text"`
		ImageKeymap map[int]models.ImageData `json:"imageKeymap"`
		Poll        *db.Poll                 `json:"poll"`
	}

	if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Bad request format")
		return
	}

	err := h.postService.NewPost(r.Context(), *currentUser, requestBody.Text, requestBody.ImageKeymap, requestBody.Poll)
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

	post, err := h.postService.GetPostById(r.Context(), *currentUser, id)
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
		posts = &[]models.DetailedPost{}
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
		posts = &[]models.DetailedPost{}
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
