import { useEffect, useState } from "react";
import { SelectComment, SelectUser } from "@/db/schema";
import { Box, Typography, Skeleton, useTheme } from "@mui/material";
import { getComments, insertComment } from "@/app/lib/actions";
import CommentInput from "./CommentInput";
import Comment from "./Comment";

interface CommentListProps {
  poster_id: number;
  post_id: number;
  commentCount: number;
  setCommentCount: (count: number) => void;
}

export default function CommentList({
  poster_id,
  post_id,
  commentCount,
  setCommentCount,
}: Readonly<CommentListProps>) {
  const theme = useTheme();
  const [comments, setComments] = useState<
    { users: SelectUser; comments: SelectComment }[]
  >([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    setIsLoading(true);
    getComments(post_id).then((comments) => {
      setComments(comments);
      setIsLoading(false);
    });
  }, [post_id]);

  const addComment = async (text: string) => {
    const result = await insertComment(text, post_id, poster_id);
    const newComment = result?.[0];

    if (!newComment) {
      return;
    }

    setCommentCount(commentCount + 1);

    const formattedComment = {
      users: newComment.users,
      comments: newComment.comments,
    };

    setComments((prevComments) => [...prevComments, formattedComment]);
    // queryClient.setQueriesData(
    //   { queryKey: ["feed"] },
    //   (oldData: { pages: PostType[][] }) => {
    //     if (!oldData) return oldData;

    //     return {
    //       ...oldData,
    //       pages: oldData.pages.map((page) =>
    //         page.map((post) =>
    //           post.post_id === post_id
    //             ? { ...post, comment_count: post.comment_count + 1 }
    //             : post
    //         )
    //       ),
    //     };
    //   }
    // );

    // console.log(
    //   "Comment added: ",
    //   queryClient.getQueriesData({ queryKey: ["feed"] })
    // );
  };

  const renderComments = () => {
    if (isLoading) {
      return (
        <>
          <Skeleton variant="rounded" height={80} sx={{ marginBottom: 2 }} />
          <Skeleton variant="rounded" height={60} sx={{ marginBottom: 2 }} />
          <Skeleton variant="rounded" height={50} />
        </>
      );
    }

    if (comments.length > 0) {
      return comments.map((comment) => (
        <Comment
          key={comment.comments.comment_id}
          comments={comment.comments}
          users={comment.users}
        />
      ));
    }

    return (
      <Typography
        variant="body2"
        sx={{ ...theme.applyStyles("dark", { color: "textSecondary" }) }}
      >
        No comments yet.
      </Typography>
    );
  };

  return (
    <Box>
      <CommentInput onAddComment={addComment} />
      <Box sx={{ marginTop: 3 }}>{renderComments()}</Box>
    </Box>
  );
}
