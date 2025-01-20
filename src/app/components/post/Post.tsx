"use client";

import React, { useState } from "react";
import { Box, Stack, Typography } from "@mui/material";
import dayjs from "dayjs";
import relativeTime from "dayjs/plugin/relativeTime";
import utc from "dayjs/plugin/utc";
import timezone from "dayjs/plugin/timezone";
import ResponsiveImage from "./images/ResponsiveImage";
import ImageModal from "./images/ImageModal";
import theme from "@/theme";
import { useRouter } from "next/navigation";
import LikeButton from "./LikeButton";
import CommentCount from "./comment/CommentCount";
import { PostType } from "@/app/data/posts";
import PostDropdown from "./PostDropdown";
import Linkify from "linkify-react";
import { User } from "@/db/schema";
import { renderMentions } from "@/app/utils/mentions";

dayjs.extend(relativeTime);
dayjs.extend(utc);
dayjs.extend(timezone);

interface Props {
  updatePost: (updatedPost: Partial<PostType>) => void;
  deletePost: (post_id: number) => void;
  user: User;
  id: number;
  date: Date;
  content: string | null;
  user_id: number;
  poster: string;
  comment_count: number;
  imagePath: string | null;
  imageWidth: number | null;
  imageHeight: number | null;
  likedByCurrentUser: boolean;
}

export default function Post({
  updatePost,
  deletePost,
  user,
  id,
  date,
  content,
  user_id,
  poster,
  comment_count,
  imagePath,
  imageWidth,
  imageHeight,
  likedByCurrentUser,
}: Readonly<Props>) {
  const router = useRouter();
  const userTimezone = dayjs.tz.guess();

  const [open, setOpen] = useState(false);
  const handleClose = () => setOpen(false);

  const options = { defaultProtocol: "https", target: "_blank" };

  interface LinkClickEvent extends React.MouseEvent<HTMLDivElement> {
    target: HTMLAnchorElement;
  }

  const handleLinkClick = (e: LinkClickEvent) => {
    if (e.target.tagName === "A") {
      e.stopPropagation();
    }
  };

  console.log("content: ", content);

  return (
    <Box
      sx={{
        borderRadius: "8px",
        margin: "10px auto",
        width: "100%",
        maxWidth: 600,
        padding: 3,
        display: "flex",
        flexDirection: "column",
        gap: 1,
        transition: "background-color 0.3s",
        background: "linear-gradient(135deg, #ffffff, #f0f0f0)",
        boxShadow: "0 2px 8px rgba(0, 0, 0, 0.2)",
        "&:hover": {
          background: "linear-gradient(135deg, #f0f0f0, #e0e0e0)",
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
      onClick={() => router.push(`/post/${id}`)}
    >
      <Stack direction="row" alignItems="center" justifyContent="space-between">
        <Typography
          sx={{
            fontSize: "11pt",
            fontWeight: 800,
            color: "#777777",
            ...theme.applyStyles("dark", { color: "#b0b0b0" }),
            "&:hover": {
              textDecoration: "underline",
            },
          }}
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            router.push(`/user/${poster}`);
          }}
        >
          @{poster}
        </Typography>
        <Box sx={{ flexGrow: 1 }} />
        {user.user_id == user_id && (
          <PostDropdown post_id={id} deletePostFromCache={deletePost} />
        )}
      </Stack>

      {content && (
        <Box
          sx={{
            color: "#333333",
            fontWeight: "bold",
            marginBottom: 3,
            ...theme.applyStyles("dark", { color: "#ffffff" }),
            whiteSpace: "pre-line",
            overflowWrap: "break-word",
            "& a": {
              color: "lightblue",
              textDecoration: "underline",
            },
            "& a:hover": {
              cursor: "pointer",
            },
          }}
        >
          <Box onClick={handleLinkClick}>
            <Linkify options={options}>{renderMentions(content)}</Linkify>
          </Box>
        </Box>
      )}

      {imagePath && imageHeight && imageWidth && (
        <Box>
          <ResponsiveImage
            imagePath={imagePath}
            width={imageWidth}
            height={imageHeight}
            setOpen={setOpen}
          />
          <ImageModal
            imagePath={imagePath}
            imageWidth={imageWidth}
            imageHeight={imageHeight}
            open={open}
            handleClose={handleClose}
          />
        </Box>
      )}

      <Stack direction="row" alignItems="center">
        <CommentCount count={comment_count} />

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
        <LikeButton
          post_id={id}
          poster_id={user_id}
          user_id={user.user_id}
          username={user.username}
          liked={likedByCurrentUser}
          updatePost={updatePost}
        />
      </Stack>
    </Box>
  );
}
