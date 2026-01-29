package handler

import (
	"encoding/json"
	"net/http"

	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"
)

// GetUserById returns a user by id, unless the target user is blocking the current user.
func (h *Handler) GetUserById(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	id, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	user, err := h.userService.GetUserById(r.Context(), *currentUser, id)
	if err != nil {
		utilities.HandleError(w, http.StatusNotFound, "This user doesn't exist")
		return
	}

	isBlocking, err := h.userService.IsBlockingUser(r.Context(), user.UserID, currentUser.UserID)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	if isBlocking {
		utilities.HandleError(w, http.StatusNotFound, "This user doesn't exist")
		return
	}

	utilities.HandleSuccess(w, user)
}

// SearchUsers takes in a prefix and returns a list of users
func (h *Handler) SearchUsers(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	prefix := r.URL.Query().Get("prefix")
	if prefix == "" {
		utilities.HandleError(w, http.StatusBadRequest, "Missing prefix")
		return
	}

	users, err := h.userService.GetUserByUsernameSearch(r.Context(), prefix, currentUser.UserID)
	if err != nil {
		utilities.HandleError(w, http.StatusNotFound, "This user doesn't exist")
		return
	}

	utilities.HandleSuccess(w, users)
}

func (h *Handler) FollowUser(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	userId, err := h.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	err = h.userService.FollowUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) UnfollowUser(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	userId, err := h.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	err = h.userService.UnfollowUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

type UpdateProfileRequest struct {
	Name              string                       `json:"name"`
	Bio               string                       `json:"bio"`
	DisplayProperties models.UserDisplayProperties `json:"displayProperties"`
}

func (h *Handler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	var request = new(UpdateProfileRequest)
	if err := json.NewDecoder(r.Body).Decode(request); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	err := h.userService.UpdateProfile(r.Context(), currentUser.UserID, &request.Name, &request.Bio, &request.DisplayProperties)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) BlockUser(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	userId, err := h.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	err = h.userService.BlockUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) UnblockUser(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	userId, err := h.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	err = h.userService.UnblockUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) MuteUser(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	userId, err := h.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	err = h.userService.MuteUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) UnmuteUser(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	userId, err := h.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	err = h.userService.UnmuteUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// Deprecated: in favor of new pagination pattern in
func (h *Handler) GetFollowersByUserId_old(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	userId, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	limit, offset := h.parsePagination(r)

	followers, err := h.userService.GetFollowersByUserId_old(r.Context(), *currentUser, userId, offset, limit)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, followers)
}

// GetFollowingByUserId returns a paginated list of followers of the current user
func (h *Handler) GetFollowingByUserId(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	userId, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	limit, before, err := h.parseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Unable to parse pagination parameters ('limit' and 'before'")
		return
	}

	users, err := h.userService.GetFollowingByUserId(r.Context(), *currentUser, userId, limit, before)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, users)
}

func (h *Handler) GetFollowingByUserId_old(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	userId, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	limit, offset := h.parsePagination(r)

	following, err := h.userService.GetFollowingByUserId_old(r.Context(), *currentUser, userId, offset, limit)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, following)
}

// Deprecated: prefer GetMutualsByUserId
func (h *Handler) GetMutualsByUserId_old(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	userId, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	limit, offset := h.parsePagination(r)

	mutuals, err := h.userService.GetMutualsByUserId_old(r.Context(), *currentUser, userId, offset, limit)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, mutuals)
}

func (h Handler) GetMutualsByUserId(w http.ResponseWriter, r *http.Request) {
	user := h.getAuthenticatedUser(r)

	targetUserId, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	limit, before, err := h.parseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Unable to parse pagination parameters ('limit' and 'before'")
		return
	}

	users, err := h.userService.GetMutualsByUserId(r.Context(), *user, targetUserId, limit, before)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, users)
}

type RequestFeaturePayload struct {
	Text string
}

func (h *Handler) RequestFeature(w http.ResponseWriter, r *http.Request) {
	currentUser := h.getAuthenticatedUser(r)

	var payload = new(RequestFeaturePayload)
	if err := json.NewDecoder(r.Body).Decode(payload); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if payload.Text == "" {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	err := h.userService.RequestFeature(r.Context(), *currentUser, payload.Text)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h Handler) AddUserToCloseFriendsList(w http.ResponseWriter, r *http.Request) {
	targetUserId, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	user := h.getAuthenticatedUser(r)

	err = h.userService.AddUserToCloseFriendsList(r.Context(), *user, targetUserId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h Handler) RemoveUserFromCloseFriendsList(w http.ResponseWriter, r *http.Request) {
	targetUserId, err := h.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	user := h.getAuthenticatedUser(r)

	err = h.userService.RemoveUserFromCloseFriendsList(r.Context(), *user, targetUserId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h Handler) ListUserCloseFriends(w http.ResponseWriter, r *http.Request) {
	limit, before, err := h.parseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Unable to parse pagination parameters ('limit' and 'before'")
		return
	}

	user := h.getAuthenticatedUser(r)

	users, err := h.userService.GetCloseFriendsByUserId(r.Context(), *user, limit, before)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, users)
}
