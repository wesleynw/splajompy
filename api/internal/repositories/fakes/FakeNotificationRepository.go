package fakes

import (
	"context"
	"github.com/jackc/pgx/v5/pgtype"
	"splajompy.com/api/v2/internal/db"
	"splajompy.com/api/v2/internal/db/queries"
	"sync"
	"time"
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
func (f *FakeNotificationRepository) InsertNotification(ctx context.Context, userId int, postId *int, commentId *int, facets *db.Facets, message string) error {
	f.mu.Lock()
	defer f.mu.Unlock()

	var postIdValue pgtype.Int4
	if postId != nil {
		postIdValue = pgtype.Int4{
			Int32: int32(*postId),
			Valid: true,
		}
	} else {
		postIdValue = pgtype.Int4{
			Valid: false,
		}
	}

	// this is dumb
	var commentIdValue pgtype.Int4
	if commentId != nil {
		commentIdValue = pgtype.Int4{
			Int32: int32(*commentId),
			Valid: true,
		}
	} else {
		commentIdValue = pgtype.Int4{
			Valid: false,
		}
	}

	notification := queries.Notification{
		NotificationID: f.nextNotificationID,
		UserID:         int32(userId),
		PostID:         postIdValue,
		Message:        message,
		CommentID:      commentIdValue,
		Viewed:         false,
		CreatedAt: pgtype.Timestamp{
			Time:  time.Now(),
			Valid: true,
		},
	}

	f.nextNotificationID++

	if _, exists := f.notifications[userId]; !exists {
		f.notifications[userId] = []queries.Notification{}
	}

	f.notifications[userId] = append(f.notifications[userId], notification)
	return nil
}

// GetNotificationsForUserId retrieves notifications for a user with pagination
func (f *FakeNotificationRepository) GetNotificationsForUserId(ctx context.Context, userId int, offset int, limit int) ([]queries.Notification, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	userNotifications, exists := f.notifications[userId]
	if !exists {
		return []queries.Notification{}, nil
	}

	// Apply pagination
	start := offset
	end := offset + limit

	if start >= len(userNotifications) {
		return []queries.Notification{}, nil
	}

	if end > len(userNotifications) {
		end = len(userNotifications)
	}

	return userNotifications[start:end], nil
}

// GetNotificationById retrieves a notification by ID
func (f *FakeNotificationRepository) GetNotificationById(ctx context.Context, notificationId int) (queries.Notification, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	// Search for the notification across all users
	for _, userNotifications := range f.notifications {
		for _, notification := range userNotifications {
			if notification.NotificationID == int32(notificationId) {
				return notification, nil
			}
		}
	}

	// Return an empty notification if not found
	return queries.Notification{}, nil
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

	// No error if notification not found
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
		// Update nextNotificationID if needed
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

func (f *FakeNotificationRepository) GetUserUnreadNotificationCount(ctx context.Context, userId int) (int, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	userNotifications, exists := f.notifications[userId]
	if !exists {
		return 0, nil
	}

	count := 0
	for _, notification := range userNotifications {
		if notification.Viewed {
			count++
		}
	}

	return count, nil
}
