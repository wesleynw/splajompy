package fakes

import (
	"context"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"splajompy.com/api/v2/internal/models"
	"splajompy.com/api/v2/internal/utilities"
)

// FakeNotificationRepository provides a fake implementation for testing
type FakeNotificationRepository struct {
	notifications      map[int][]queries.Notification
	nextNotificationID int32
	mu                 sync.Mutex
}

// NewFakeNotificationRepository creates a new fake notification repository
func NewFakeNotificationRepository() *FakeNotificationRepository {
	return &FakeNotificationRepository{
		notifications:      make(map[int][]queries.Notification),
		nextNotificationID: 1,
		mu:                 sync.Mutex{},
	}
}

// InsertNotification adds a new notification
func (f *FakeNotificationRepository) InsertNotification(ctx context.Context, userId int, postId *int, commentId *int, facets *db.Facets, message string, notificationType models.NotificationType) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	var postIdValue pgtype.Int4
	if postId != nil {
		postIdValue = pgtype.Int4{
			Int32: int32(*postId),
			Valid: true,
		}
	}

	var commentIdValue pgtype.Int4
	if commentId != nil {
		commentIdValue = pgtype.Int4{
			Int32: int32(*commentId),
			Valid: true,
		}
	}

	var facetsValue db.Facets
	if facets != nil {
		facetsValue = *facets
	}

	notification := queries.Notification{
		NotificationID:   f.nextNotificationID,
		UserID:           int32(userId),
		PostID:           postIdValue,
		Message:          message,
		CommentID:        commentIdValue,
		Facets:           facetsValue,
		NotificationType: notificationType.String(),
		Viewed:           false,
		CreatedAt:        pgtype.Timestamp{Time: time.Now()},
	}

	f.nextNotificationID++

	if _, exists := f.notifications[userId]; !exists {
		f.notifications[userId] = []queries.Notification{}
	}

	f.notifications[userId] = append(f.notifications[userId], notification)
	return nil
}

// GetNotificationsForUserId retrieves notifications for a user with pagination
func (f *FakeNotificationRepository) GetNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]*models.Notification, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	userNotifications, exists := f.notifications[userId]
	if !exists {
		return []*models.Notification{}, nil
	}

	// Apply pagination
	start := offset
	end := offset + limit

	if start >= len(userNotifications) {
		return []*models.Notification{}, nil
	}

	if end > len(userNotifications) {
		end = len(userNotifications)
	}

	result := make([]*models.Notification, 0, end-start)
	for _, notification := range userNotifications[start:end] {
		mapped := utilities.MapNotification(notification)
		result = append(result, &mapped)
	}

	return result, nil
}

// GetNotificationById retrieves a notification by ID
func (f *FakeNotificationRepository) GetNotificationById(ctx context.Context, notificationId int) (*models.Notification, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	// Search for the notification across all users
	for _, userNotifications := range f.notifications {
		for _, notification := range userNotifications {
			if notification.NotificationID == int32(notificationId) {
				mapped := utilities.MapNotification(notification)
				return &mapped, nil
			}
		}
	}

	// Return nil if not found
	return nil, nil
}

// MarkNotificationAsRead marks a notification as read
func (f *FakeNotificationRepository) MarkNotificationAsRead(ctx context.Context, notificationId int) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	// Find and update the notification
	for userId, userNotifications := range f.notifications {
		for i, notification := range userNotifications {
			if notification.NotificationID == int32(notificationId) {
				userNotifications[i].Viewed = true
				f.notifications[userId] = userNotifications
				return nil
			}
		}
	}

	return nil
}

// MarkAllNotificationsAsReadForUser marks all notifications as read for a user
func (f *FakeNotificationRepository) MarkAllNotificationsAsReadForUser(ctx context.Context, userId int) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	userNotifications, exists := f.notifications[userId]
	if !exists {
		return nil
	}

	for i := range userNotifications {
		userNotifications[i].Viewed = true
	}

	f.notifications[userId] = userNotifications
	return nil
}

// GetUserHasUnreadNotifications checks if a user has unread notifications
func (f *FakeNotificationRepository) GetUserHasUnreadNotifications(ctx context.Context, userId int) (bool, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	userNotifications, exists := f.notifications[userId]
	if !exists {
		return false, nil
	}

	for _, notification := range userNotifications {
		if !notification.Viewed {
			return true, nil
		}
	}

	return false, nil
}

func (f *FakeNotificationRepository) GetUserUnreadNotificationCount(ctx context.Context, userId int) (int, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	userNotifications, exists := f.notifications[userId]
	if !exists {
		return 0, nil
	}

	count := 0
	for _, notification := range userNotifications {
		if !notification.Viewed {
			count++
		}
	}

	return count, nil
}

// GetUnreadNotificationsForUserId retrieves unread notifications for a user with pagination
func (f *FakeNotificationRepository) GetUnreadNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]*models.Notification, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	userNotifications, exists := f.notifications[userId]
	if !exists {
		return []*models.Notification{}, nil
	}

	// Filter to only unread notifications
	unreadNotifications := make([]queries.Notification, 0)
	for _, notification := range userNotifications {
		if !notification.Viewed {
			unreadNotifications = append(unreadNotifications, notification)
		}
	}

	// Apply pagination
	start := offset
	end := offset + limit

	if start >= len(unreadNotifications) {
		return []*models.Notification{}, nil
	}

	if end > len(unreadNotifications) {
		end = len(unreadNotifications)
	}

	result := make([]*models.Notification, 0, end-start)
	for _, notification := range unreadNotifications[start:end] {
		mapped := utilities.MapNotification(notification)
		result = append(result, &mapped)
	}

	return result, nil
}

// AddNotification adds a pre-defined notification for testing
func (f *FakeNotificationRepository) AddNotification(notification queries.Notification) {
	f.mu.Lock()
	defer f.mu.Unlock()

	userId := int(notification.UserID)

	if _, exists := f.notifications[userId]; !exists {
		f.notifications[userId] = []queries.Notification{}
	}

	// Ensure notification ID is set
	if notification.NotificationID == 0 {
		notification.NotificationID = f.nextNotificationID
		f.nextNotificationID++
	} else if notification.NotificationID >= f.nextNotificationID {
		f.nextNotificationID = notification.NotificationID + 1
	}

	f.notifications[userId] = append(f.notifications[userId], notification)
}

// ClearNotifications removes all notifications
func (f *FakeNotificationRepository) ClearNotifications() {
	f.mu.Lock()
	defer f.mu.Unlock()

	f.notifications = make(map[int][]queries.Notification)
	f.nextNotificationID = 1
}

// GetNotificationCount returns the number of notifications for a user
func (f *FakeNotificationRepository) GetNotificationCount(userId int) int {
	f.mu.Lock()
	defer f.mu.Unlock()

	if userNotifications, exists := f.notifications[userId]; exists {
		return len(userNotifications)
	}

	return 0
}

// GetUnreadNotificationCount returns the number of unread notifications for a user
func (f *FakeNotificationRepository) GetUnreadNotificationCount(userId int) int {
	f.mu.Lock()
	defer f.mu.Unlock()

	count := 0
	if userNotifications, exists := f.notifications[userId]; exists {
		for _, notification := range userNotifications {
			if !notification.Viewed {
				count++
			}
		}
	}

	return count
}

// GetReadNotificationsForUserIdWithTimeOffset retrieves read notifications for a user with time-based pagination
func (f *FakeNotificationRepository) GetReadNotificationsForUserIdWithTimeOffset(ctx context.Context, userId int, beforeTime time.Time, limit int) ([]*models.Notification, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	userNotifications, exists := f.notifications[userId]
	if !exists {
		return []*models.Notification{}, nil
	}

	// Filter to only read notifications that are before the given time
	filteredNotifications := make([]queries.Notification, 0)
	for _, notification := range userNotifications {
		if notification.Viewed && notification.CreatedAt.Time.Before(beforeTime) {
			filteredNotifications = append(filteredNotifications, notification)
		}
	}

	// Limit results
	if limit > 0 && len(filteredNotifications) > limit {
		filteredNotifications = filteredNotifications[:limit]
	}

	result := make([]*models.Notification, 0, len(filteredNotifications))
	for _, notification := range filteredNotifications {
		mapped := utilities.MapNotification(notification)
		result = append(result, &mapped)
	}

	return result, nil
}

// GetUnreadNotificationsForUserIdWithTimeOffset retrieves unread notifications for a user with time-based pagination
func (f *FakeNotificationRepository) GetUnreadNotificationsForUserIdWithTimeOffset(ctx context.Context, userId int, beforeTime time.Time, limit int) ([]*models.Notification, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	userNotifications, exists := f.notifications[userId]
	if !exists {
		return []*models.Notification{}, nil
	}

	// Filter to only unread notifications that are before the given time
	filteredNotifications := make([]queries.Notification, 0)
	for _, notification := range userNotifications {
		if !notification.Viewed && notification.CreatedAt.Time.Before(beforeTime) {
			filteredNotifications = append(filteredNotifications, notification)
		}
	}

	// Limit results
	if limit > 0 && len(filteredNotifications) > limit {
		filteredNotifications = filteredNotifications[:limit]
	}

	result := make([]*models.Notification, 0, len(filteredNotifications))
	for _, notification := range filteredNotifications {
		mapped := utilities.MapNotification(notification)
		result = append(result, &mapped)
	}

	return result, nil
}

func (f *FakeNotificationRepository) FindUnreadLikeNotification(ctx context.Context, userId int, postId int, commentId *int) (*models.Notification, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	userNotifications, exists := f.notifications[userId]
	if !exists {
		return nil, nil
	}

	for _, notification := range userNotifications {
		if notification.NotificationType == "like" && !notification.Viewed {
			if commentId == nil {
				if notification.PostID.Valid && int(notification.PostID.Int32) == postId && !notification.CommentID.Valid {
					mapped := utilities.MapNotification(notification)
					return &mapped, nil
				}
			} else {
				if notification.PostID.Valid && int(notification.PostID.Int32) == postId &&
					notification.CommentID.Valid && int(notification.CommentID.Int32) == *commentId {
					mapped := utilities.MapNotification(notification)
					return &mapped, nil
				}
			}
		}
	}

	return nil, nil
}

func (f *FakeNotificationRepository) DeleteNotificationById(ctx context.Context, notificationId int) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	for userId, userNotifications := range f.notifications {
		for i, notification := range userNotifications {
			if notification.NotificationID == int32(notificationId) {
				f.notifications[userId] = append(userNotifications[:i], userNotifications[i+1:]...)
				return nil
			}
		}
	}

	return nil
}
