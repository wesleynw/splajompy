import { Box, Button, CircularProgress, Typography } from "@mui/material";

export default function SubmitPostButton({
  isLoading,
  disabled,
}: Readonly<{ isLoading: boolean; disabled: boolean }>) {
  return (
    <Button
      type="submit"
      variant="contained"
      sx={{
        borderRadius: "22px",
        padding: "4px 12px",
        backgroundColor: "#4a90e2",
        color: "#ffffff",
        fontWeight: "bold",
        textTransform: "none",
        "&:hover": {
          backgroundColor: "#357abf",
        },
        position: "relative",
      }}
      disabled={isLoading || disabled}
    >
      {isLoading && (
        <Box
          sx={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            position: "absolute",
            top: 0,
            left: 0,
            width: "100%",
            height: "100%",
          }}
        >
          <CircularProgress size="1.5rem" sx={{ color: "inherit" }} />
        </Box>
      )}

      <Typography
        variant="subtitle1"
        fontWeight={800}
        style={{ visibility: isLoading ? "hidden" : "visible" }}
      >
        Post
      </Typography>
    </Button>
  );
}
