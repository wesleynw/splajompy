package handler

import (
	"encoding/json"
	"net/http"

	"splajompy.com/api/v2/internal/models"
)

// GET /post/{id}/comments
func (h *Handler) GetCommentsByPost(w http.ResponseWriter, r *http.Request) {
	_, currentUser, err := h.validateSessionToken(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	comments, err := h.commentService.GetCommentsByPostId(r.Context(), *currentUser, int(id))
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if err := h.writeJSON(w, comments, http.StatusOK); err != nil {
		http.Error(w, "Error encoding response", http.StatusInternalServerError)
		return
	}
}

// POST /post/{id}/comment
func (h *Handler) AddCommentToPostById(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	post_id, err := h.GetIntPathParam(r, "post_id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	var requestBody struct {
		Text string
	}
	if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	dbComment, err := h.commentService.AddCommentToPost(r.Context(), *currentUser, post_id, requestBody.Text)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
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

	if err := h.writeJSON(w, comment, http.StatusOK); err != nil {
		http.Error(w, "Error encoding response", http.StatusInternalServerError)
		return
	}
}

// POST /post/{post_id}/comment/{comment_id}/liked
func (h *Handler) AddCommentLike(w http.ResponseWriter, r *http.Request) {
	_, currentUser, err := h.validateSessionToken(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	post_id, err := h.GetIntPathParam(r, "post_id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	comment_id, err := h.GetIntPathParam(r, "comment_id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err = h.commentService.AddLikeToCommentById(r.Context(), *currentUser, post_id, comment_id)
	if err != nil {
		http.Error(w, "Error adding like", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// DELETE /post/{post_id}/comment/{comment_id}/liked
func (h *Handler) RemoveCommentLike(w http.ResponseWriter, r *http.Request) {
	_, cUser, err := h.validateSessionToken(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	post_id, err := h.GetIntPathParam(r, "post_id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	comment_id, err := h.GetIntPathParam(r, "comment_id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	err = h.commentService.RemoveLikeFromCommentById(r.Context(), *cUser, post_id, comment_id)
	if err != nil {
		http.Error(w, "Error adding like", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
