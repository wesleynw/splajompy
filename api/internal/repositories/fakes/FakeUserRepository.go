package fakes

import (
	"context"
	"errors"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/repositories"
)

type FakeUserRepository struct {
	users                 map[int]models.PublicUser
	usersByUsername       map[string]int
	usersByEmail          map[string]int
	userBios              map[int]string
	userDisplayProperties map[int]models.UserDisplayProperties
	passwords             map[int]string
	followRelations       map[int]map[int]bool
	blockRelations        map[int]map[int]bool
	muteRelations         map[int]map[int]bool
	verificationCodes     map[int]map[string]queries.VerificationCode
	sessions              map[string]queries.Session
	mutex                 sync.RWMutex
	nextUserId            int
	userRelationships     map[int]map[int]time.Time
}

func NewFakeUserRepository() repositories.UserRepository {
	return &FakeUserRepository{
		users:                 make(map[int]models.PublicUser),
		usersByUsername:       make(map[string]int),
		usersByEmail:          make(map[string]int),
		userBios:              make(map[int]string),
		userDisplayProperties: make(map[int]models.UserDisplayProperties),
		passwords:             make(map[int]string),
		followRelations:       make(map[int]map[int]bool),
		blockRelations:        make(map[int]map[int]bool),
		muteRelations:         make(map[int]map[int]bool),
		verificationCodes:     make(map[int]map[string]queries.VerificationCode),
		sessions:              make(map[string]queries.Session),
		nextUserId:            1,
		userRelationships:     make(map[int]map[int]time.Time),
	}
}

func (r *FakeUserRepository) GetUserById(ctx context.Context, userId int) (models.PublicUser, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	id := userId
	user, exists := r.users[id]
	if !exists {
		return models.PublicUser{}, errors.New("user not found")
	}

	return user, nil
}

func (r *FakeUserRepository) GetUserByUsername(ctx context.Context, username string) (models.PublicUser, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	userId, exists := r.usersByUsername[username]
	if !exists {
		return models.PublicUser{}, errors.New("user not found")
	}

	return r.users[userId], nil
}

func (r *FakeUserRepository) GetUserByIdentifier(ctx context.Context, identifier string) (models.PublicUser, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	// Check if identifier is an email
	if userId, exists := r.usersByEmail[identifier]; exists {
		return r.users[userId], nil
	}

	// Check if identifier is a username
	if userId, exists := r.usersByUsername[identifier]; exists {
		return r.users[userId], nil
	}

	return models.PublicUser{}, errors.New("user not found")
}

func (r *FakeUserRepository) GetBioForUser(ctx context.Context, userId int) (string, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	id := userId
	if _, exists := r.users[id]; !exists {
		return "", errors.New("user not found")
	}

	bio, exists := r.userBios[id]
	if !exists {
		return "", nil
	}

	return bio, nil
}

func (r *FakeUserRepository) UpdateBio(ctx context.Context, userId int, bio string) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	id := userId
	if _, exists := r.users[id]; !exists {
		return errors.New("user not found")
	}

	r.userBios[id] = bio
	return nil
}

func (r *FakeUserRepository) IsUserFollowingUser(ctx context.Context, followerId int, followingId int) (bool, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	fId := followerId
	if _, exists := r.users[fId]; !exists {
		return false, errors.New("follower not found")
	}

	tId := followingId
	if _, exists := r.users[tId]; !exists {
		return false, errors.New("following user not found")
	}

	following, exists := r.followRelations[fId]
	if !exists {
		return false, nil
	}

	return following[tId], nil
}

func (r *FakeUserRepository) FollowUser(_ context.Context, followerId int, followingId int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	fId := followerId
	if _, exists := r.users[fId]; !exists {
		return errors.New("follower not found")
	}

	tId := followingId
	if _, exists := r.users[tId]; !exists {
		return errors.New("following user not found")
	}

	if r.followRelations[fId] == nil {
		r.followRelations[fId] = make(map[int]bool)
	}

	r.followRelations[fId][tId] = true
	return nil
}

func (r *FakeUserRepository) UnfollowUser(ctx context.Context, followerId int, followingId int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	fId := followerId
	if _, exists := r.users[fId]; !exists {
		return errors.New("follower not found")
	}

	tId := followingId
	if _, exists := r.users[tId]; !exists {
		return errors.New("following user not found")
	}

	if r.followRelations[fId] != nil {
		delete(r.followRelations[fId], tId)
	}

	return nil
}

func (r *FakeUserRepository) SearchUsername(ctx context.Context, prefix string, limit int, currentUserId int) ([]models.PublicUser, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var matchingUsers []models.PublicUser

	for _, user := range r.users {
		if strings.HasPrefix(strings.ToLower(user.Username), strings.ToLower(prefix)) {
			matchingUsers = append(matchingUsers, user)
			if len(matchingUsers) >= limit {
				break
			}
		}
	}

	return matchingUsers, nil
}

func (r *FakeUserRepository) UpdateUserName(ctx context.Context, userId int, newName string) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	id := userId
	user, exists := r.users[id]
	if !exists {
		return errors.New("user not found")
	}

	user.Name = newName
	r.users[id] = user

	return nil
}

func (r *FakeUserRepository) GetUserDisplayProperties(ctx context.Context, userId int) (*db.UserDisplayProperties, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	if _, exists := r.users[userId]; !exists {
		return nil, errors.New("user not found")
	}

	props, exists := r.userDisplayProperties[userId]
	if !exists {
		return nil, nil
	}

	return &db.UserDisplayProperties{
		FontChoiceId:     props.FontChoiceId,
		LatestAppVersion: props.LatestAppVersion,
		LastLoginDate:    props.LastLoginDate,
	}, nil
}

func (r *FakeUserRepository) UpdateUserDisplayProperties(ctx context.Context, userId int, displayProperties *db.UserDisplayProperties) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	id := userId
	if _, exists := r.users[id]; !exists {
		return errors.New("user not found")
	}

	r.userDisplayProperties[id] = models.UserDisplayProperties{
		FontChoiceId:     displayProperties.FontChoiceId,
		LatestAppVersion: displayProperties.LatestAppVersion,
		LastLoginDate:    displayProperties.LastLoginDate,
	}

	return nil
}

func (r *FakeUserRepository) GetIsUsernameInUse(ctx context.Context, username string) (bool, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	_, exists := r.usersByUsername[username]
	return exists, nil
}

func (r *FakeUserRepository) GetIsEmailInUse(ctx context.Context, email string) (bool, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	_, exists := r.usersByEmail[email]
	return exists, nil
}

func (r *FakeUserRepository) CreateUser(ctx context.Context, username string, email string, password string, _ string) (models.PublicUser, error) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	// Check if username is already in use
	if _, exists := r.usersByUsername[username]; exists {
		return models.PublicUser{}, errors.New("username already in use")
	}

	// Check if email is already in use
	if _, exists := r.usersByEmail[email]; exists {
		return models.PublicUser{}, errors.New("email already in use")
	}

	userId := r.nextUserId
	r.nextUserId++

	now := time.Now()
	user := models.PublicUser{
		UserID:    userId,
		Email:     email,
		Username:  username,
		CreatedAt: now.UTC(),
		Name:      "",
	}

	r.users[userId] = user
	r.usersByUsername[username] = userId
	r.usersByEmail[email] = userId
	r.passwords[userId] = password
	r.followRelations[userId] = make(map[int]bool)

	return user, nil
}

func (r *FakeUserRepository) GetVerificationCode(ctx context.Context, userId int, code string) (queries.VerificationCode, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	id := userId
	if _, exists := r.users[id]; !exists {
		return queries.VerificationCode{}, errors.New("user not found")
	}

	codes, exists := r.verificationCodes[id]
	if !exists {
		return queries.VerificationCode{}, errors.New("verification code not found")
	}

	verCode, exists := codes[code]
	if !exists {
		return queries.VerificationCode{}, errors.New("verification code not found")
	}

	return verCode, nil
}

func (r *FakeUserRepository) CreateVerificationCode(ctx context.Context, userId int, code string, expiresAt time.Time) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	id := userId
	if _, exists := r.users[id]; !exists {
		return errors.New("user not found")
	}

	if r.verificationCodes[id] == nil {
		r.verificationCodes[id] = make(map[string]queries.VerificationCode)
	}

	r.verificationCodes[id][code] = queries.VerificationCode{
		UserID:    userId,
		Code:      code,
		ExpiresAt: pgtype.Timestamp{Time: expiresAt, Valid: true},
	}

	return nil
}

func (r *FakeUserRepository) GetUserPasswordByIdentifier(ctx context.Context, identifier string) (string, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var userId int
	var exists bool

	// Check if identifier is an email
	if userId, exists = r.usersByEmail[identifier]; !exists {
		// Check if identifier is a username
		if userId, exists = r.usersByUsername[identifier]; !exists {
			return "", errors.New("user not found")
		}
	}

	password, exists := r.passwords[userId]
	if !exists {
		return "", errors.New("password not found")
	}

	return password, nil
}

func (r *FakeUserRepository) CreateSession(ctx context.Context, sessionId string, userId int, expiresAt time.Time) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	id := userId
	if _, exists := r.users[id]; !exists {
		return errors.New("user not found")
	}

	r.sessions[sessionId] = queries.Session{
		ID:        sessionId,
		UserID:    userId,
		ExpiresAt: pgtype.Timestamp{Time: expiresAt, Valid: true},
	}

	return nil
}

// Helper methods specific to the fake implementation

func (r *FakeUserRepository) GetSessionById(sessionId string) (queries.Session, bool) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	session, exists := r.sessions[sessionId]
	return session, exists
}

func (r *FakeUserRepository) DeleteSession(sessionId string) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	delete(r.sessions, sessionId)
}

func (r *FakeUserRepository) SetUserBio(userId int, bio string) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	r.userBios[userId] = bio
}

func (r *FakeUserRepository) GetFollowersForUser(userId int) []int {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var followers []int
	id := userId

	for followerId, following := range r.followRelations {
		if following[id] {
			followers = append(followers, followerId)
		}
	}

	return followers
}

func (r *FakeUserRepository) GetFollowingForUser(userId int) []int {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	id := userId
	following, exists := r.followRelations[id]
	if !exists {
		return []int{}
	}

	var followingIds []int
	for followingId, isFollowing := range following {
		if isFollowing {
			followingIds = append(followingIds, followingId)
		}
	}

	return followingIds
}

func (r *FakeUserRepository) BlockUser(_ context.Context, currentUserId int, targetUserId int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if r.blockRelations[currentUserId] == nil {
		r.blockRelations[currentUserId] = make(map[int]bool)
	}

	r.blockRelations[currentUserId][targetUserId] = true
	return nil
}

func (r *FakeUserRepository) UnblockUser(_ context.Context, currentUserId int, targetUserId int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if r.blockRelations[currentUserId] != nil {
		delete(r.blockRelations[currentUserId], targetUserId)
	}

	return nil
}

func (r *FakeUserRepository) IsUserBlockingUser(_ context.Context, blockerId int, blockedId int) (bool, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	if r.blockRelations[blockerId] == nil {
		return false, nil
	}

	return r.blockRelations[blockerId][blockedId], nil
}

func (r *FakeUserRepository) MuteUser(_ context.Context, currentUserId int, targetUserId int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if r.muteRelations[currentUserId] == nil {
		r.muteRelations[currentUserId] = make(map[int]bool)
	}

	r.muteRelations[currentUserId][targetUserId] = true
	return nil
}

func (r *FakeUserRepository) UnmuteUser(_ context.Context, currentUserId int, targetUserId int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if r.muteRelations[currentUserId] != nil {
		delete(r.muteRelations[currentUserId], targetUserId)
	}

	return nil
}

func (r *FakeUserRepository) IsUserMutingUser(_ context.Context, muterId int, mutedId int) (bool, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	if r.muteRelations[muterId] == nil {
		return false, nil
	}

	return r.muteRelations[muterId][mutedId], nil
}

func (r *FakeUserRepository) DeleteAccount(ctx context.Context, userId int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	id := userId
	user, exists := r.users[id]
	if !exists {
		return errors.New("user not found")
	}

	// Clean up user mappings first (before deleting the user)
	delete(r.usersByUsername, user.Username)
	delete(r.usersByEmail, user.Email)

	// Delete the user
	delete(r.users, id)
	delete(r.userBios, id)
	delete(r.passwords, id)
	delete(r.followRelations, id)
	delete(r.verificationCodes, id)

	// Remove user from other users' follow relations
	for userIdKey, following := range r.followRelations {
		delete(following, id)
		r.followRelations[userIdKey] = following
	}

	// Clean up sessions
	for sessionId, session := range r.sessions {
		if session.UserID == userId {
			delete(r.sessions, sessionId)
		}
	}

	return nil
}

func (r *FakeUserRepository) GetMutualConnectionsForUser(ctx context.Context, userId1 int, userId2 int) ([]string, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	return nil, nil
}

func (r *FakeUserRepository) GetFollowersByUserId_old(ctx context.Context, userId int, limit int, offset int) ([]queries.GetFollowersByUserIdRow, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var followers []queries.GetFollowersByUserIdRow

	// Find all users who follow the given userId
	for followerId, following := range r.followRelations {
		if following[userId] {
			if user, exists := r.users[followerId]; exists {
				var name pgtype.Text
				if user.Name != "" {
					name = pgtype.Text{String: user.Name, Valid: true}
				}

				followers = append(followers, queries.GetFollowersByUserIdRow{
					UserID:    followerId,
					Email:     user.Email,
					Username:  user.Username,
					CreatedAt: pgtype.Timestamp{Time: user.CreatedAt, Valid: true},
					Name:      name,
				})
			}
		}
	}

	// Simple pagination
	start := offset
	end := offset + limit
	if start >= len(followers) {
		return []queries.GetFollowersByUserIdRow{}, nil
	}
	if end > len(followers) {
		end = len(followers)
	}

	return followers[start:end], nil
}

// TODO
func (r *FakeUserRepository) GetFollowersByUserId(ctx context.Context, userId int, limit int, before *time.Time) ([]models.PublicUser, error) {
	return nil, nil
}

// TODO
func (r *FakeUserRepository) GetFollowingUserIds(ctx context.Context, userId int, limit int, before *time.Time) ([]int, error) {
	return nil, nil
}

func (r *FakeUserRepository) GetFollowingByUserId_old(ctx context.Context, userId int, limit int, offset int) ([]queries.GetFollowingByUserIdRow, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var following []queries.GetFollowingByUserIdRow

	// Get the users that the given userId is following
	if userFollowing, exists := r.followRelations[userId]; exists {
		for followingId, isFollowing := range userFollowing {
			if isFollowing {
				if user, exists := r.users[followingId]; exists {
					var name pgtype.Text
					if user.Name != "" {
						name = pgtype.Text{String: user.Name, Valid: true}
					}

					following = append(following, queries.GetFollowingByUserIdRow{
						UserID:    followingId,
						Email:     user.Email,
						Username:  user.Username,
						CreatedAt: pgtype.Timestamp{Time: user.CreatedAt, Valid: true},
						Name:      name,
					})
				}
			}
		}
	}

	// Simple pagination
	start := offset
	end := offset + limit
	if start >= len(following) {
		return []queries.GetFollowingByUserIdRow{}, nil
	}
	if end > len(following) {
		end = len(following)
	}

	return following[start:end], nil
}

func (r *FakeUserRepository) GetMutualsByUserId_old(ctx context.Context, currentUserId int, targetUserId int, limit int, offset int) ([]queries.GetMutualsByUserIdRow, error) {
	r.mutex.RLock()
	defer r.mutex.RUnlock()

	var mutuals []queries.GetMutualsByUserIdRow

	// Get the users that both currentUserId and targetUserId follow
	currentUserFollowing, currentExists := r.followRelations[currentUserId]
	targetUserFollowing, targetExists := r.followRelations[targetUserId]

	if currentExists && targetExists {
		for followingId := range currentUserFollowing {
			// Check if targetUserId also follows this user
			if currentUserFollowing[followingId] && targetUserFollowing[followingId] {
				if user, exists := r.users[followingId]; exists {
					var name pgtype.Text
					if user.Name != "" {
						name = pgtype.Text{String: user.Name, Valid: true}
					}

					mutuals = append(mutuals, queries.GetMutualsByUserIdRow{
						UserID:    followingId,
						Email:     user.Email,
						Username:  user.Username,
						CreatedAt: pgtype.Timestamp{Time: user.CreatedAt, Valid: true},
						Name:      name,
					})
				}
			}
		}
	}

	// Simple pagination
	start := offset
	end := offset + limit
	if start >= len(mutuals) {
		return []queries.GetMutualsByUserIdRow{}, nil
	}
	if end > len(mutuals) {
		end = len(mutuals)
	}

	return mutuals[start:end], nil
}

// TODO
func (r *FakeUserRepository) GetMutualUserIds(ctx context.Context, userId int, targetUserId int, limit int, before *time.Time) ([]int, error) {
	return nil, nil
}

func (r *FakeUserRepository) GetIsReferralCodeInUse(ctx context.Context, code string) (bool, error) {
	return false, nil
}

func (r *FakeUserRepository) AddUserRelationship(ctx context.Context, userId int, targetUserId int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if r.userRelationships[userId] == nil {
		r.userRelationships[userId] = make(map[int]time.Time)
	}

	r.userRelationships[userId][targetUserId] = time.Now()

	return nil
}

func (r *FakeUserRepository) RemoveUserRelationship(ctx context.Context, userId int, targetUserId int) error {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	if r.userRelationships[userId] != nil {
		delete(r.userRelationships[userId], targetUserId)
	}

	return nil
}

func (r *FakeUserRepository) GetRelationshipByUserId(ctx context.Context, userId int, limit int, before *time.Time) ([]models.PublicUser, error) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	var users []models.PublicUser
	if r.userRelationships[userId] == nil {
		return users, nil
	}

	for targetUserId, createdAt := range r.userRelationships[userId] {
		if before == nil || !createdAt.Before(*before) {
			user := r.users[targetUserId]
			users = append(users, user)
		}
	}

	return users, nil
}

func (r *FakeUserRepository) GetRelationshipUserIds(ctx context.Context, userId int, limit int, before *time.Time) ([]int, error) {
	r.mutex.Lock()
	defer r.mutex.Unlock()

	var userIds []int
	if r.userRelationships[userId] == nil {
		return userIds, nil
	}

	for targetUserId, createdAt := range r.userRelationships[userId] {
		if before == nil || !createdAt.Before(*before) {
			userIds = append(userIds, targetUserId)
		}
	}

	return userIds, nil
}
