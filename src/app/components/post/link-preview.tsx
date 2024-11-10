import React, { useEffect, useState } from "react";
import { Box, Typography, Avatar, useTheme, Skeleton } from "@mui/material";
import { Launch } from "@mui/icons-material";
import { OgObject } from "open-graph-scraper/types";
import LinkPreviewFetcher from "@/app/lib/link-preview-fetcher";

interface LinkPreviewProps {
  linkUrl: string;
}

export default function LinkPreview({ linkUrl }: Readonly<LinkPreviewProps>) {
  const theme = useTheme();
  const [ogResult, setOgResult] = useState<OgObject | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    async function fetchData() {
      setIsLoading(true);
      const result = await LinkPreviewFetcher(linkUrl);
      setOgResult(result);
      setIsLoading(false);
    }

    if (linkUrl) {
      fetchData();
    }
  }, [linkUrl]);

  if (isLoading) {
    return (
      <Box
        sx={{
          display: "flex",
          alignItems: "center",
          padding: 2,
          borderRadius: "8px",
          backgroundColor:
            theme.palette.mode === "dark"
              ? theme.palette.background.paper
              : "#333",
          boxShadow: "0 2px 6px rgba(0, 0, 0, 0.1)",
        }}
      >
        <Skeleton
          variant="circular"
          width={32}
          height={32}
          sx={{ marginRight: 2, backgroundColor: theme.palette.grey[700] }}
        />
        <Skeleton
          variant="text"
          width="60%"
          height={24}
          sx={{ backgroundColor: theme.palette.grey[700] }}
        />
      </Box>
    );
  }

  return (
    <Box
      onClick={(event) => {
        event.stopPropagation();
        window.open(linkUrl, "_blank", "noopener,noreferrer");
      }}
      sx={{
        display: "flex",
        alignItems: "center",
        padding: 2,
        borderRadius: "8px",
        backgroundColor: theme.palette.background.paper,
        boxShadow: "0 2px 6px rgba(0, 0, 0, 0.1)",
        cursor: "pointer",
        "&:hover": {
          backgroundColor: theme.palette.action.hover,
          boxShadow: "0 4px 8px rgba(0, 0, 0, 0.2)",
        },
      }}
    >
      {ogResult?.favicon ? (
        <Avatar
          sx={{
            width: 32,
            height: 32,
            marginRight: 2,
            objectFit: "contain",
            backgroundColor: "transparent",
          }}
          src={ogResult.favicon}
          alt="Favicon"
        />
      ) : (
        <Avatar
          sx={{
            width: 32,
            height: 32,
            marginRight: 2,
            backgroundColor: theme.palette.grey[300],
            objectFit: "contain",
          }}
        >
          ✕
        </Avatar>
      )}
      <Typography
        variant="body2"
        sx={{
          fontWeight: "bold",
          color: theme.palette.text.primary,
          overflow: "hidden",
          textOverflow: "ellipsis",
          whiteSpace: "nowrap",
          flex: 1,
          userSelect: "none",
        }}
      >
        {ogResult?.ogTitle ?? ogResult?.requestUrl}
      </Typography>
      <Launch />
    </Box>
  );
}
