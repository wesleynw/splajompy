package comment

import (
	"encoding/json"
	"net/http"

	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) RegisterRoutes(withAuth func(string, func(http.ResponseWriter, *http.Request))) {
	withAuth("POST /post/{post_id}/comment", h.AddCommentToPostById)
	withAuth("POST /post/{post_id}/comment/{comment_id}/liked", h.AddCommentLike)
	withAuth("DELETE /post/{post_id}/comment/{comment_id}/liked", h.RemoveCommentLike)
	withAuth("DELETE /comment/{comment_id}", h.DeleteComment)
	withAuth("GET /post/{id}/comments", h.GetCommentsByPost)
}

func (h *Handler) GetCommentsByPost(w http.ResponseWriter, r *http.Request) {
	id, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusUnauthorized, "Missing parameter")
		return
	}

	currentUser := utilities.GetAuthenticatedUser(r)
	comments, err := h.svc.GetCommentsByPostId(r.Context(), *currentUser, id)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, comments)
}

// AddCommentToPostById POST /post/{id}/comment
func (h *Handler) AddCommentToPostById(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	postId, err := utilities.GetIntPathParam(r, "post_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	var requestBody struct {
		Text        string
		ImageKeyMap map[int]models.ImageData `json:"imageKeyMap"`
	}

	if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	comment, err := h.svc.AddCommentToPost(r.Context(), *currentUser, postId, requestBody.Text, requestBody.ImageKeyMap)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, comment)
}

func (h *Handler) AddCommentLike(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	postId, err := utilities.GetIntPathParam(r, "post_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	commentId, err := utilities.GetIntPathParam(r, "comment_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	err = h.svc.AddLikeToCommentById(r.Context(), *currentUser, postId, commentId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// RemoveCommentLike DELETE /post/{post_id}/comment/{comment_id}/liked
func (h *Handler) RemoveCommentLike(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	postId, err := utilities.GetIntPathParam(r, "post_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	commentId, err := utilities.GetIntPathParam(r, "comment_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	err = h.svc.RemoveLikeFromCommentById(r.Context(), *currentUser, postId, commentId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// DeleteComment DELETE /comment/{comment_id}
func (h *Handler) DeleteComment(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	commentId, err := utilities.GetIntPathParam(r, "comment_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing parameter")
		return
	}

	err = h.svc.DeleteComment(r.Context(), *currentUser, commentId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}
