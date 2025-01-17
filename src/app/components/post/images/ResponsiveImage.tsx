/* eslint-disable @next/next/no-img-element */
import React from "react";
import { Box } from "@mui/material";

interface ResponsiveImageProps {
  imagePath: string;
  width: number;
  height: number;
  setOpen: React.Dispatch<React.SetStateAction<boolean>>;
}

export default function ResponsiveImage({
  imagePath,
  width,
  height,
  setOpen,
}: Readonly<ResponsiveImageProps>) {
  const threshold = 2;
  const isTall = height / width > threshold;
  const isWide = width / height > threshold;
  const isNonStandardSize = isTall || isWide;

  const src = `https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/${imagePath}`;

  return (
    <Box
      onClick={(e) => {
        e.stopPropagation();
        e.preventDefault();
        setOpen(true);
      }}
      sx={{
        display: "inline-flex",
        overflow: "hidden",
        padding: 0,
        margin: 0,
        maxWidth: "100%",
      }}
    >
      <img
        alt="Image"
        src={src}
        style={{
          objectFit: isNonStandardSize ? "cover" : "contain",
          maxHeight: isTall ? "200px" : "510px",
          maxWidth: isTall ? "300px" : "100%",
          minWidth: "50%",
          minHeight: "100px",
          borderRadius: "8px",
          cursor: "pointer",
        }}
      />
    </Box>
  );
}
