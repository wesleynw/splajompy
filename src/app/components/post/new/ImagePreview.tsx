import React, { useEffect, useState } from "react";
import Box from "@mui/material/Box";
import IconButton from "@mui/material/IconButton";
import CloseIcon from "@mui/icons-material/Close";
import Image from "next/image";

interface ImagePreviewProps {
  previewFile: File | null;
  setFile: (file: File | null) => void;
  setPreviewFile: (file: File | null) => void;
}

export default function ImagePreview({
  previewFile,
  setFile,
  setPreviewFile,
}: Readonly<ImagePreviewProps>) {
  const [imageSrc, setImageSrc] = useState<string | null>(null);

  useEffect(() => {
    if (!previewFile) {
      setImageSrc(null);
      return;
    }

    const objectUrl = URL.createObjectURL(previewFile);
    setImageSrc(objectUrl);

    return () => {
      URL.revokeObjectURL(objectUrl);
    };
  }, [previewFile]);

  const handleFileRemove = () => {
    setFile(null);
    setPreviewFile(null);
  };

  if (!imageSrc) {
    return null;
  }

  return (
    <Box
      sx={{
        marginBottom: 2,
        position: "relative",
        width: "100%",
        minHeight: "100px",
        maxHeight: "300px",
        borderRadius: "8px",
        overflow: "hidden",
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        backgroundColor: "rgba(0, 0, 0, 0.1)",
      }}
    >
      <Image
        src={imageSrc}
        alt="Selected preview"
        width={0}
        height={0}
        sizes="100vw"
        style={{
          width: "100%",
          height: "auto",
          objectFit: "contain",
          cursor: "pointer",
        }}
      />
      <IconButton
        onClick={handleFileRemove}
        sx={{
          position: "absolute",
          top: 4,
          right: 4,
          backgroundColor: "rgba(0, 0, 0, 0.5)",
          color: "white",
          "&:hover": { backgroundColor: "rgba(0, 0, 0, 0.7)" },
        }}
      >
        <CloseIcon />
      </IconButton>
    </Box>
  );
}
