package handler

import (
	"encoding/json"
	"net/http"

	"splajompy.com/api/v2/internal/models"
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

	comments, err := h.commentService.GetCommentsByPostId(r.Context(), *currentUser, int(id))
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, comments)
}

// POST /post/{id}/comment
func (h *Handler) AddCommentToPostById(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	post_id, err := h.GetIntPathParam(r, "post_id")
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

	dbComment, err := h.commentService.AddCommentToPost(r.Context(), *currentUser, post_id, requestBody.Text)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	comment := models.DetailedComment{
		CommentID: dbComment.CommentID,
		PostID:    dbComment.PostID,
		UserID:    dbComment.UserID,
		Text:      dbComment.Text,
		CreatedAt: dbComment.CreatedAt,
		User:      *currentUser,
		IsLiked:   false,
	}

	utilities.HandleSuccess(w, comment)
}

func (h *Handler) AddCommentLike(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	post_id, err := h.GetIntPathParam(r, "post_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	comment_id, err := h.GetIntPathParam(r, "comment_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	err = h.commentService.AddLikeToCommentById(r.Context(), *currentUser, post_id, comment_id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// DELETE /post/{post_id}/comment/{comment_id}/liked
func (h *Handler) RemoveCommentLike(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	post_id, err := h.GetIntPathParam(r, "post_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	comment_id, err := h.GetIntPathParam(r, "comment_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	err = h.commentService.RemoveLikeFromCommentById(r.Context(), *currentUser, post_id, comment_id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}
