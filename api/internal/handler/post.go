package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"

	"splajompy.com/api/v2/internal/db"
)

// GET /post/{id}
func (h *Handler) GetPostById(w http.ResponseWriter, r *http.Request) {
	session, err := h.getAuthenticatedUser(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	post, err := h.postService.GetPostById(r.Context(), *session, id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if err := h.writeJSON(w, post, http.StatusOK); err != nil {
		http.Error(w, "Error encoding response", http.StatusInternalServerError)
		return
	}
}

// GET user/{id}/posts
func (h *Handler) GetPostsByUserId(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
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
		http.Error(w, "unable to return posts", http.StatusInternalServerError)
		return
	}

	if err := h.writeJSON(w, posts, http.StatusOK); err != nil {
		http.Error(w, "Error encoding response", http.StatusInternalServerError)
	}
}

// GET /posts/following endpoint
func (h *Handler) GetPostsByFollowing(w http.ResponseWriter, r *http.Request) {
	_, user, err := h.validateSessionToken(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	// Parse pagination parameters
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

	// Get posts from following users
	posts, err := h.queries.GetAllPostsByFollowing(r.Context(), db.GetAllPostsByFollowingParams{
		UserID: user.UserID,
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		http.Error(w, "Error fetching posts", http.StatusInternalServerError)
		return
	}

	// Return empty array instead of null if no posts
	if posts == nil {
		posts = []db.GetAllPostsByFollowingRow{}
	}

	// Create response with posts and their images
	type PostWithImages struct {
		db.GetAllPostsByFollowingRow
		Images []db.Image
	}

	response := make([]PostWithImages, len(posts))

	// Fetch images for each post
	for i, post := range posts {
		// Copy post data
		response[i].GetAllPostsByFollowingRow = post

		// Get images for this post
		images, err := h.queries.GetImagesByPostId(r.Context(), post.PostID)
		if err != nil {
			log.Printf("Error fetching images for post %d: %v", post.PostID, err)
			// Continue with empty images rather than failing the whole request
			images = []db.Image{}
		}

		if images == nil {
			images = []db.Image{}
		}

		response[i].Images = images
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, "Error encoding response", http.StatusInternalServerError)
	}
}

// AddPostLike handles the POST /post/{id}/liked endpoint
func (h *Handler) AddPostLike(w http.ResponseWriter, r *http.Request) {
	// Authenticate user
	_, user, err := h.validateSessionToken(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	err = h.postService.AddLikeToPost(r.Context(), *user, id)
	if err != nil {
		http.Error(w, "Error adding like", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// RemovePostLike handles the DELETE /post/{id}/liked endpoint
func (h *Handler) RemovePostLike(w http.ResponseWriter, r *http.Request) {
	// Authenticate user
	_, user, err := h.validateSessionToken(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
		return
	}

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	err = h.postService.RemoveLikeFromPost(r.Context(), *user, id)
	if err != nil {
		http.Error(w, "Error removing like", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
