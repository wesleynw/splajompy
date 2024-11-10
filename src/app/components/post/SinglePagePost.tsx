"use client";

import { Box, Stack, Typography, useTheme } from "@mui/material";
import dayjs from "dayjs";
import relativeTime from "dayjs/plugin/relativeTime";
import utc from "dayjs/plugin/utc";
import timezone from "dayjs/plugin/timezone";
import { Suspense } from "react";
import CommentList from "./comment/CommentList";
import { SelectPost, SelectUser } from "@/db/schema";
import BackButton from "../navigation/back-button";
import LinkPreviewComponent from "./link-preview";
import { OgObject } from "open-graph-scraper/types";
import { parseLinks } from "@/app/lib/parse-links";

dayjs.extend(relativeTime);
dayjs.extend(utc);
dayjs.extend(timezone);

interface Props {
  post: SelectUser & SelectPost;
  ogResult: OgObject | null;
}

export default function Page({ post }: Readonly<Props>) {
  const theme = useTheme();
  const userTimezone = dayjs.tz.guess();

  return (
    <Box
      sx={{
        maxWidth: 600,
        margin: "6px auto",
        padding: 3,
        borderRadius: "12px",
        backgroundColor: "background.paper",
        background: "linear-gradient(135deg, #ffffff, #f5f5f5)",
        boxShadow: "0 2px 8px rgba(0, 0, 0, 0.2)",
        ...theme.applyStyles("dark", {
          background: "linear-gradient(135deg, #1b1b1b, #222222)",
          boxShadow: "0 2px 4px rgba(0, 0, 0, 0.5)",
        }),
      }}
    >
      <Stack direction="row" alignItems="center" sx={{ marginBottom: 2 }}>
        <BackButton />
      </Stack>

      <Typography
        variant="subtitle2"
        sx={{
          color: theme.palette.text.secondary,
          alignSelf: "flex-end",
        }}
      >
        @{post.username}
      </Typography>

      <Typography
        variant="h6"
        sx={{
          color: theme.palette.text.primary,
          fontWeight: "bold",
          marginBottom: 2,
        }}
      >
        {parseLinks(post.text)}
      </Typography>

      {post.link && <LinkPreviewComponent linkUrl={post.link} />}

      <Typography
        variant="body2"
        sx={{
          color: theme.palette.text.secondary,
          marginBottom: 1,
          marginTop: 1,
        }}
      >
        {dayjs.utc(post.postdate).tz(userTimezone).fromNow()}
      </Typography>

      <Suspense fallback={<div>Loading...</div>}>
        <CommentList post_id={post.post_id} />
      </Suspense>
    </Box>
  );
}
