package apns

import "splajompy.com/api/v2/internal/models"

type Notification struct {
	Payload     NotificationPayload
	DeviceToken string
}

type NotificationPayload struct {
	Aps        Aps                     `json:"aps"`
	Type       models.NotificationType `json:"type"`
	Identifier int                     `json:"identifier"`
}

type NotificationResponse struct {
	Reason string `json:"reason"`
}

type Aps struct {
	Alert     Alert `json:"alert"`
	Badge     int   `json:"badge"`
	Timestamp int64 `json:"timestamp"`
}

type Alert struct {
	Title    string `json:"title"`
	Subtitle string `json:"subtitle"`
	Body     string `json:"body"`
}
