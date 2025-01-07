"use client";

import theme from "@/theme";
import { Box, Typography, Stack } from "@mui/material";
import Notification from "./Notification";
import { useNotifications } from "@/app/data/notifications";
import Spinner from "../loading/Spinner";
import { useEffect, useRef, useState } from "react";

export default function NotificationView() {
  const { isPending, notifications, markRead } = useNotifications();
  const [recentlyViewed, setRecentlyViewed] = useState(new Set());

  const markReadRef = useRef(markRead);

  useEffect(() => {
    if (isPending || !notifications) return;

    const markNotificationsAsRead = async () => {
      const newRecentlyViewed = new Set(
        notifications?.filter((n) => !n.viewed).map((n) => n.notification_id)
      );
      setRecentlyViewed(newRecentlyViewed);
      await markReadRef.current();
    };

    const timer = setTimeout(markNotificationsAsRead, 1000);

    return () => clearTimeout(timer);
  }, [isPending]);

  if (isPending) {
    return <Spinner />;
  }

  if (!notifications || notifications.length === 0) {
    return (
      <Box
        sx={{
          maxWidth: 600,
          margin: "20px auto",
          padding: 3,
          borderRadius: "8px",
        }}
      >
        <Typography
          variant="h6"
          sx={{
            textAlign: "center",
            color: "#777777",
            ...theme.applyStyles("dark", { color: "#bbb" }),
          }}
        >
          No notifications yet.
        </Typography>
      </Box>
    );
  }

  return (
    <Box
      sx={{
        maxWidth: 600,
        margin: "auto",
        marginTop: "10px",
        marginBottom: "100px",
        px: { xs: 2, md: 4 },
        boxSizing: "border-box",
        borderRadius: "8px",
      }}
    >
      <Stack spacing={2} sx={{ cursor: "pointer" }}>
        {notifications.map((notification) => (
          <Notification
            key={notification.notification_id}
            notification={notification}
            recentlyViewed={recentlyViewed.has(notification.notification_id)}
          />
        ))}
      </Stack>
    </Box>
  );
}
