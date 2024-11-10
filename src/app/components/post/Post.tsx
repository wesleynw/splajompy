"use client";

import { Box, Stack, Typography, useTheme } from "@mui/material";
import dayjs from "dayjs";
import relativeTime from "dayjs/plugin/relativeTime";
import utc from "dayjs/plugin/utc";
import timezone from "dayjs/plugin/timezone";
import LinkPreview from "./link-preview";
import { useRouter } from "next/navigation";
import { parseLinks } from "@/app/lib/parse-links";

dayjs.extend(relativeTime);
dayjs.extend(utc);
dayjs.extend(timezone);

interface Props {
  id: number;
  date: Date;
  content: string;
  poster: string;
  comment_count: number;
  link: string | null;
}

export default function Post({
  id,
  date,
  content,
  poster,
  comment_count,
  link,
}: Readonly<Props>) {
  const userTimezone = dayjs.tz.guess();
  const theme = useTheme();
  const router = useRouter();

  return (
    <Box
      onClick={() => router.push(`/post/${id}`)}
      sx={{
        maxWidth: 500,
        padding: 2,
        margin: "16px auto",
        borderRadius: "8px",
        display: "flex",
        flexDirection: "column",
        gap: 1,
        textDecoration: "none",
        transition: "background-color 0.3s, box-shadow 0.3s",
        background: "linear-gradient(135deg, #ffffff, #f0f0f0)",
        boxShadow: "0 2px 8px rgba(0, 0, 0, 0.2)",
        "&:hover": {
          background: "linear-gradient(135deg, #f0f0f0, #e0e0e0)",
          boxShadow: "0 4px 12px rgba(0, 0, 0, 0.3)",
          cursor: "pointer",
        },
        ...theme.applyStyles("dark", {
          background: "linear-gradient(135deg, #1b1b1b, #222222)",
          boxShadow: "0 2px 4px rgba(0, 0, 0, 0.5)",
          "&:hover": {
            background: "linear-gradient(135deg, #222222, #2a2a2a)",
          },
        }),
      }}
    >
      <Typography
        variant="subtitle2"
        sx={{
          color: "#777777",
          ...theme.applyStyles("dark", { color: "#b0b0b0" }),
        }}
      >
        @{poster}
      </Typography>

      <Typography
        variant="body1"
        sx={{
          color: "#333333",
          fontWeight: "bold",
          marginBottom: 1,
          ...theme.applyStyles("dark", { color: "#ffffff" }),
        }}
      >
        {parseLinks(content)}
      </Typography>

      {link && <LinkPreview linkUrl={link} />}

      <Stack direction="row" alignItems="center">
        <Typography
          variant="subtitle2"
          sx={{
            color: "#777777",
            fontSize: 14,
            ...theme.applyStyles("dark", { color: "#b0b0b0" }),
          }}
        >
          {comment_count} comment{comment_count === 1 ? "" : "s"}
        </Typography>

        <Box sx={{ flexGrow: 1 }} />

        <Typography
          variant="body2"
          sx={{
            color: "#555555",
            ...theme.applyStyles("dark", { color: "#e0e0e0" }),
          }}
        >
          {dayjs.utc(date).tz(userTimezone).fromNow()}
        </Typography>
      </Stack>
    </Box>
  );
}
