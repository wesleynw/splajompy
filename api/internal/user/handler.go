package user

import (
	"encoding/json"
	"errors"
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

func (h *Handler) RegisterRoutes(_, withAuth func(string, func(http.ResponseWriter, *http.Request))) {
	// blocking
	withAuth("POST /user/{user_id}/block", h.BlockUser)
	withAuth("DELETE /user/{user_id}/block", h.UnblockUser)

	// muting
	withAuth("POST /user/{user_id}/mute", h.MuteUser)
	withAuth("DELETE /user/{user_id}/mute", h.UnmuteUser)

	// users
	withAuth("GET /user/{id}", h.GetUserById)
	withAuth("GET /v2/user/{id}/following", h.GetFollowingByUserId)
	withAuth("GET /v3/user/{id}/following", h.GetFollowingByUserId)
	withAuth("GET /v2/user/{id}/mutuals", h.GetMutualsByUserId)
	withAuth("GET /v3/user/{id}/mutuals", h.GetMutualsByUserIdV3)
	withAuth("GET /users/notification/{id}", h.ListNotificationActors)
	withAuth("GET /users/search", h.SearchUsers)

	withAuth("POST /user/{id}/friend", h.AddUserToCloseFriendsList)
	withAuth("DELETE /user/{id}/friend", h.RemoveUserFromCloseFriendsList)
	withAuth("GET /user/friends", h.ListUserCloseFriends)
	withAuth("GET /v2/user/friends", h.ListUserCloseFriendsV2)

	withAuth("POST /request-feature", h.RequestFeature)

	// follow
	withAuth("POST /follow/{user_id}", h.FollowUser)
	withAuth("DELETE /follow/{user_id}", h.UnfollowUser)

	withAuth("POST /user/profile", h.UpdateProfile)

}

// GetUserById returns a user by id, unless the target user is blocking the current user.
func (h *Handler) GetUserById(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	id, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	user, err := h.svc.GetUserById(r.Context(), currentUser.UserID, id)
	if err != nil {
		utilities.HandleError(w, http.StatusNotFound, "This user doesn't exist")
		return
	}

	isBlocking, err := h.svc.IsBlockingUser(r.Context(), user.UserID, currentUser.UserID)
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
	currentUser := utilities.GetAuthenticatedUser(r)

	prefix := r.URL.Query().Get("prefix")
	if prefix == "" {
		utilities.HandleError(w, http.StatusBadRequest, "Missing prefix")
		return
	}

	users, err := h.svc.GetUserByUsernameSearch(r.Context(), prefix, currentUser.UserID)
	if err != nil {
		utilities.HandleError(w, http.StatusNotFound, "This user doesn't exist")
		return
	}

	utilities.HandleSuccess(w, users)
}

func (h *Handler) FollowUser(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	userId, err := utilities.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	err = h.svc.FollowUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) UnfollowUser(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	userId, err := utilities.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	err = h.svc.UnfollowUser(r.Context(), *currentUser, userId)
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
	currentUser := utilities.GetAuthenticatedUser(r)

	var request = new(UpdateProfileRequest)
	if err := json.NewDecoder(r.Body).Decode(request); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	err := h.svc.UpdateProfile(r.Context(), currentUser.UserID, &request.Name, &request.Bio, &request.DisplayProperties)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) BlockUser(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	userId, err := utilities.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	err = h.svc.BlockUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) UnblockUser(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	userId, err := utilities.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	err = h.svc.UnblockUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) MuteUser(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	userId, err := utilities.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	err = h.svc.MuteUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h *Handler) UnmuteUser(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	userId, err := utilities.GetIntPathParam(r, "user_id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	err = h.svc.UnmuteUser(r.Context(), *currentUser, userId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

// GetFollowingByUserId returns a paginated list of users the given user follows.
func (h *Handler) GetFollowingByUserId(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	userId, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	limit, before, err := utilities.ParseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Unable to parse pagination parameters ('limit' and 'before'")
		return
	}

	result, err := h.svc.GetFollowingByUserId(r.Context(), *currentUser, userId, limit, before)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, result)
}

func (h *Handler) GetMutualsByUserId(w http.ResponseWriter, r *http.Request) {
	user := utilities.GetAuthenticatedUser(r)

	targetUserId, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	limit, before, err := utilities.ParseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Unable to parse pagination parameters ('limit' and 'before'")
		return
	}

	result, err := h.svc.GetMutualsByUserId(r.Context(), *user, targetUserId, limit, before)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, result.Users)
}

func (h *Handler) GetMutualsByUserIdV3(w http.ResponseWriter, r *http.Request) {
	user := utilities.GetAuthenticatedUser(r)

	targetUserId, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing user ID parameter")
		return
	}

	limit, before, err := utilities.ParseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Unable to parse pagination parameters ('limit' and 'before'")
		return
	}

	result, err := h.svc.GetMutualsByUserId(r.Context(), *user, targetUserId, limit, before)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, result)
}

type RequestFeaturePayload struct {
	Text string
}

func (h *Handler) RequestFeature(w http.ResponseWriter, r *http.Request) {
	currentUser := utilities.GetAuthenticatedUser(r)

	var payload = new(RequestFeaturePayload)
	if err := json.NewDecoder(r.Body).Decode(payload); err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if payload.Text == "" {
		utilities.HandleError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	err := h.svc.RequestFeature(r.Context(), *currentUser, payload.Text)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h Handler) AddUserToCloseFriendsList(w http.ResponseWriter, r *http.Request) {
	targetUserId, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	user := utilities.GetAuthenticatedUser(r)

	err = h.svc.AddUserToCloseFriendsList(r.Context(), *user, targetUserId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h Handler) RemoveUserFromCloseFriendsList(w http.ResponseWriter, r *http.Request) {
	targetUserId, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	user := utilities.GetAuthenticatedUser(r)

	err = h.svc.RemoveUserFromCloseFriendsList(r.Context(), *user, targetUserId)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleEmptySuccess(w)
}

func (h Handler) ListUserCloseFriends(w http.ResponseWriter, r *http.Request) {
	limit, before, err := utilities.ParseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Unable to parse pagination parameters ('limit' and 'before'")
		return
	}

	user := utilities.GetAuthenticatedUser(r)

	result, err := h.svc.GetCloseFriendsByUserId(r.Context(), *user, limit, before)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, result.Users)
}

func (h *Handler) ListNotificationActors(w http.ResponseWriter, r *http.Request) {
	notificationId, err := utilities.GetIntPathParam(r, "id")
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Missing ID parameter")
		return
	}

	limit, before, err := utilities.ParseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Unable to parse pagination parameters ('limit' and 'before'")
		return
	}

	user := utilities.GetAuthenticatedUser(r)

	result, err := h.svc.GetNotificationActors(r.Context(), user.UserID, notificationId, limit, before)
	if err != nil {
		if errors.Is(err, utilities.ErrUnauthorized) {
			utilities.HandleError(w, http.StatusForbidden, "Unauthorized")
			return
		}
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, result)
}

func (h Handler) ListUserCloseFriendsV2(w http.ResponseWriter, r *http.Request) {
	limit, before, err := utilities.ParseTimeBasedPagination(r)
	if err != nil {
		utilities.HandleError(w, http.StatusBadRequest, "Unable to parse pagination parameters ('limit' and 'before'")
		return
	}

	user := utilities.GetAuthenticatedUser(r)

	result, err := h.svc.GetCloseFriendsByUserId(r.Context(), *user, limit, before)
	if err != nil {
		utilities.HandleError(w, http.StatusInternalServerError, "Something went wrong")
		return
	}

	utilities.HandleSuccess(w, result)
}
