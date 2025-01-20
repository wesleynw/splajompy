import theme from "@/theme";
import { Box, TextField, Button } from "@mui/material";
import { useState } from "react";

interface Props {
  onAddComment: (text: string) => void;
}

export default function CommentInput({ onAddComment }: Readonly<Props>) {
  const [comment, setComment] = useState("");

  const handleAddComment = () => {
    if (comment.trim()) {
      onAddComment(comment);
      setComment("");
    }
  };

  return (
    <Box sx={{ marginTop: 3 }}>
      <TextField
        fullWidth
        variant="outlined"
        placeholder={`Add a comment...`}
        value={comment}
        onChange={(e) => setComment(e.target.value)}
        sx={{ marginBottom: 2 }}
      />
      <Button
        variant="contained"
        onClick={handleAddComment}
        disabled={!comment.trim()}
        sx={{
          borderRadius: "24px",
          padding: "8px 24px",
          textTransform: "none",
          backgroundColor: "#1976d2",
          color: "white",
          boxShadow: "none",
          "&:hover": {
            backgroundColor: "#ffffff",
            color: "#1976d2",
          },
          "&:disabled": {
            backgroundColor: "#e0e0e0",
            color: "#9e9e9e",
          },
          ...theme.applyStyles("dark", {
            backgroundColor: "#424242",
            "&:hover": {
              backgroundColor: "#ffffff",
              color: "#424242",
            },
            "&:disabled": {
              backgroundColor: "#555555",
              color: "#888888",
            },
          }),
        }}
      >
        Post Comment
      </Button>
    </Box>
  );
}
