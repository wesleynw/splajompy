package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"
)

func (h *Handler) CreateNewPost(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	var requestBody struct {
		Text        string         `json:"text"`
		ImageKeymap map[int]string `json:"imageKeymap"`
	}

	if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Bad request format")
		return
	}

	err = h.postService.NewPost(r.Context(), *currentUser, requestBody.Text, requestBody.ImageKeymap)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) GetPresignedUrl(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

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
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

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
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

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

func (h *Handler) GetPostsByUserId(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	limit := 10
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
		}
	}

	offset := 0
	if offsetStr := r.URL.Query().Get("offset"); offsetStr != "" {
		if parsedOffset, err := strconv.Atoi(offsetStr); err == nil && parsedOffset >= 0 {
			offset = parsedOffset
		}
	}

	posts, err := h.postService.GetPostsByUserId(r.Context(), *currentUser, id, limit, offset)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, posts)
}

func (h *Handler) GetAllPosts(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	limit := 10
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
		}
	}

	offset := 0
	if offsetStr := r.URL.Query().Get("offset"); offsetStr != "" {
		if parsedOffset, err := strconv.Atoi(offsetStr); err == nil && parsedOffset >= 0 {
			offset = parsedOffset
		}
	}

	posts, err := h.postService.GetAllPosts(r.Context(), *currentUser, limit, offset)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, posts)
}

func (h *Handler) GetPostsByFollowing(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	limit := 10
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
		}
	}

	offset := 0
	if offsetStr := r.URL.Query().Get("offset"); offsetStr != "" {
		if parsedOffset, err := strconv.Atoi(offsetStr); err == nil && parsedOffset >= 0 {
			offset = parsedOffset
		}
	}

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

func (h *Handler) AddPostLike(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

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
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

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
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

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
