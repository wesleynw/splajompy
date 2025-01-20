"use client";

import { Dialog, DialogContent, Slide } from "@mui/material";
import { TransitionProps } from "@mui/material/transitions";
import { forwardRef, useRef } from "react";
import { RichTextareaHandle } from "rich-textarea";
import NewPost from "./NewPost";
import { User } from "@/db/schema";

type Props = {
  user: User;
  open: boolean;
  toggleOpen: () => void;
};

const Transition = forwardRef<unknown, TransitionProps>((props, ref) => (
  <Slide direction="down" ref={ref} {...props}>
    {props.children as React.ReactElement}
  </Slide>
));
Transition.displayName = "Transition";

export default function NewPostDialog({
  user,
  open,
  toggleOpen,
}: Readonly<Props>) {
  const inputRef = useRef<RichTextareaHandle>(null);

  return (
    <Dialog
      open={open}
      onClose={toggleOpen}
      onTransitionEnd={() => inputRef.current?.focus()}
      TransitionComponent={Transition}
      fullScreen
      keepMounted
      sx={{
        top: "60px",
        "& .MuiDialog-container": {
          backgroundColor: "transparent",
        },
        "& .MuiDialog-paper": {
          backgroundColor: "transparent !important",
          overflow: "hidden",
          zIndex: 1299,
          "--Paper-overlay": "transparent !important",
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
          position: "relative",
          top: "20px",
          width: "100%",
          height: "100%",
          padding: 0,
        }}
      >
        <NewPost
          user={user}
          onPost={toggleOpen}
          insertPostToCache={() => console.log("a")} // TODO: why is this here?
          inputRef={inputRef}
        />
      </DialogContent>
    </Dialog>
  );
}
