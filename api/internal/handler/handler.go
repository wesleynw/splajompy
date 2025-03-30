package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/service"
)

type Handler struct {
	queries        *db.Queries
	postService    *service.PostService
	commentService *service.CommentService
	userService    *service.UserService
}

func NewHandler(queries db.Queries, postService *service.PostService, commentService *service.CommentService, userService *service.UserService) *Handler {
	return &Handler{
		queries:        &queries,
		postService:    postService,
		commentService: commentService,
		userService:    userService,
	}
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /login", h.Login)

	mux.HandleFunc("GET /post/{id}", h.GetPostById)
	mux.HandleFunc("GET /user/{id}/posts", h.GetPostsByUserId)

	// likes
	mux.HandleFunc("POST /post/{id}/liked", h.AddPostLike)
	mux.HandleFunc("DELETE /post/{id}/liked", h.RemovePostLike)

	// comments
	mux.HandleFunc("POST /post/{post_id}/comment", h.AddCommentToPostById)
	mux.HandleFunc("POST /post/{post_id}/comment/{comment_id}/liked", h.AddCommentLike)
	mux.HandleFunc("DELETE /post/{post_id}/comment/{comment_id}/liked", h.RemoveCommentLike)

	mux.HandleFunc("GET /user/{id}", h.GetUserById)
	mux.HandleFunc("GET /posts/following", h.GetPostsByFollowing)

	// comments
	mux.HandleFunc("GET /post/{id}/comments", h.GetCommentsByPost)
}

func (h *Handler) getAuthenticatedUser(r *http.Request) (*models.PublicUser, error) {
	_, user, err := h.validateSessionToken(r.Context(), r.Header.Get("Authorization"))
	return user, err
}

func (h *Handler) writeJSON(w http.ResponseWriter, data interface{}, statusCode int) error {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	return json.NewEncoder(w).Encode(data)
}

func (h *Handler) GetIntPathParam(r *http.Request, paramName string) (int, error) {
	paramString := r.PathValue(paramName)
	if paramString == "" {
		return 0, errors.New("missing url paramter")
	}
	param, err := strconv.Atoi(paramString)
	if err != nil {
		return 0, errors.New("cannot parse url parameter")
	}

	return param, nil
}
