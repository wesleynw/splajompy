import { Box, CircularProgress } from "@mui/material";

function WordLimitCircularProgress({
  progressPercentage,
}: {
  progressPercentage: number;
}) {
  return (
    <Box position="relative" display="inline-flex">
      <CircularProgress
        size={20}
        variant="determinate"
        value={100}
        thickness={5}
        sx={{ color: "lightgray" }}
      />

      <CircularProgress
        size={20}
        variant="determinate"
        value={progressPercentage}
        thickness={6}
        sx={{
          color: "#4a90e2",
          position: "absolute",
          top: 0,
          left: 0,
        }}
      />
    </Box>
  );
}

export default WordLimitCircularProgress;
