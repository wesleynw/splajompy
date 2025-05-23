package handler

import (
	"encoding/json"
	"net/http"

	"splajompy.com/api/v2/internal/utilities"
)

func (h *Handler) GetCommentsByPost(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Missing parameter")
		return
	}

	comments, err := h.commentService.GetCommentsByPostId(r.Context(), *currentUser, id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, comments)
}

// AddCommentToPostById POST /post/{id}/comment
func (h *Handler) AddCommentToPostById(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	postId, err := h.GetIntPathParam(r, "post_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	var requestBody struct {
		Text string
	}

	if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	comment, err := h.commentService.AddCommentToPost(r.Context(), *currentUser, postId, requestBody.Text)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, comment)
}

func (h *Handler) AddCommentLike(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	postId, err := h.GetIntPathParam(r, "post_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	commentId, err := h.GetIntPathParam(r, "comment_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	err = h.commentService.AddLikeToCommentById(r.Context(), *currentUser, postId, commentId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// RemoveCommentLike DELETE /post/{post_id}/comment/{comment_id}/liked
func (h *Handler) RemoveCommentLike(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	postId, err := h.GetIntPathParam(r, "post_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	commentId, err := h.GetIntPathParam(r, "comment_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	err = h.commentService.RemoveLikeFromCommentById(r.Context(), *currentUser, postId, commentId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}
