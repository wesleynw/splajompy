"use client";

import { Dialog, DialogContent, Slide } from "@mui/material";
import { TransitionProps } from "@mui/material/transitions";
import { forwardRef, useRef, useEffect } from "react";
import NewPost from "./NewPost";

type Props = {
  open: boolean;
  toggleOpen: () => void;
};

const Transition = forwardRef<unknown, TransitionProps>((props, ref) => (
  <Slide direction="down" ref={ref} {...props}>
    {props.children as React.ReactElement}
  </Slide>
));
Transition.displayName = "Transition";

export default function NewPostDialog({ open, toggleOpen }: Readonly<Props>) {
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const setBodyStylesForOpen = () => {
      document.body.style.position = "fixed";
      document.body.style.width = "100%";
      document.body.style.height = "100%";
      document.body.style.overflow = "hidden";
      document.body.style.touchAction = "none";
    };

    const resetBodyStyles = () => {
      document.body.style.position = "";
      document.body.style.width = "";
      document.body.style.height = "";
      document.body.style.overflow = "";
      document.body.style.touchAction = "";
    };

    if (open) {
      setBodyStylesForOpen();
    } else {
      resetBodyStyles();
    }
  }, [open]);

  return (
    <Dialog
      open={open}
      onClose={toggleOpen}
      onTransitionEnd={() => inputRef.current?.focus()}
      TransitionComponent={Transition}
      fullScreen // Cover the full viewport
      sx={{
        top: "60px",
        "& .MuiDialog-container": {
          // backdropFilter: "blur(10px)", // Blur effect on background
          backgroundColor: "transparent", // Completely transparent backdrop
        },
        "& .MuiDialog-paper": {
          boxShadow: "none", // Remove shadow
          backgroundColor: "transparent !important", // Transparent dialog content
          overflow: "hidden",
          zIndex: 1299, // Ensure it's above other elements
          "--Paper-overlay": "transparent !important", // Override MUI's CSS variable
        },
      }}
      slotProps={{
        backdrop: {
          sx: { backdropFilter: "blur(10px)", color: "transparent" },
        },
      }}
      PaperProps={{ color: "transparent" }}
    >
      <DialogContent
        sx={{
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          width: "100%", // Fill width
          height: "100%", // Fill height
          padding: 0, // Remove padding
        }}
      >
        <NewPost
          onPost={toggleOpen}
          insertPostToCache={() => console.log("a")}
          inputRef={inputRef}
        />
      </DialogContent>
    </Dialog>
  );
}
