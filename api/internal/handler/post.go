package handler

import (
	"encoding/json"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"

	"splajompy.com/api/v2/internal/models"
)

// POST /post/new
// this could use a little refactor to keep it more organized
func (h *Handler) NewPost(w http.ResponseWriter, r *http.Request) {
	var err error

	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
	}

	var text string

	// posts contains image(s)
	if strings.HasPrefix(r.Header.Get("Content-Type"), "multipart/form-data") {
		err = r.ParseMultipartForm(10 << 20) // 10mb max
		if err != nil {
			http.Error(w, "Failed to parse form: "+err.Error(), http.StatusBadRequest)
			return
		}

		jsonStr := r.FormValue("json")

		var requestBody struct {
			Text string `json:"text"`
		}

		if jsonStr != "" {
			if err := json.Unmarshal([]byte(jsonStr), &requestBody); err != nil {
				http.Error(w, "Invalid JSON: "+err.Error(), http.StatusBadRequest)
				return
			}
		}

		text = requestBody.Text

		file, fileHeader, err := r.FormFile("image")
		if err != nil {
			http.Error(w, "Error retrieving the file", http.StatusBadRequest)
			return
		}
		defer func() {
			if err := file.Close(); err != nil {
				http.Error(w, "Error closing file: "+err.Error(), http.StatusInternalServerError)
			}
		}()

		if fileHeader.Size > 2*1024*1024 {
			http.Error(w, "File size exceeds 2MB limit,", http.StatusBadRequest)
			return
		}

		fileType := fileHeader.Header.Get("Content-Type")
		if !strings.HasPrefix(fileType, "image/") {
			http.Error(w, "File type not allowed. Only images are accepted.", http.StatusBadRequest)
			return
		}

		fileExt := filepath.Ext(fileHeader.Filename)

		buffer := make([]byte, fileHeader.Size)
		if _, err := file.Read(buffer); err != nil {
			http.Error(w, "Error reading file.", http.StatusInternalServerError)
			return
		}

		err = h.postService.NewPost(r.Context(), *currentUser, text, &buffer, &fileType, &fileExt)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
	} else {
		var requestBody struct {
			Text string `json:"text"`
		}

		if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		text = requestBody.Text
		err = h.postService.NewPost(r.Context(), *currentUser, text, nil, nil, nil)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
	}
}

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

// GET /posts/all
func (h *Handler) GetAllPosts(w http.ResponseWriter, r *http.Request) {
	currentUser, err := h.getAuthenticatedUser(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
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
		http.Error(w, "Error fetching posts", http.StatusInternalServerError)
		return
	}

	if err := h.writeJSON(w, posts, http.StatusOK); err != nil {
		http.Error(w, "Error encoding response", http.StatusInternalServerError)
	}
}

// GET /posts/following endpoint
func (h *Handler) GetPostsByFollowing(w http.ResponseWriter, r *http.Request) {
	_, currentUser, err := h.validateSessionToken(r.Context(), r.Header.Get("Authorization"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnauthorized)
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
		http.Error(w, "Error fetching posts", http.StatusInternalServerError)
		return
	}

	if posts == nil {
		posts = &[]models.DetailedPost{}
	}

	if err := h.writeJSON(w, posts, http.StatusOK); err != nil {
		http.Error(w, "Error encoding response", http.StatusInternalServerError)
	}
}

// POST /post/{id}/liked endpoint
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

// DELETE /post/{id}/liked endpoint
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
