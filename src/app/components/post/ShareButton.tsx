import { useState } from "react";
import IosShareIcon from "@mui/icons-material/IosShare";
import { IconButton, Snackbar } from "@mui/material";

export default function ShareButton() {
  const [open, setOpen] = useState(false);

  const handleClick = async () => {
    if (navigator.share && navigator.canShare({ url: window.location.href })) {
      try {
        await navigator.share({ url: window.location.href });
      } catch (error) {
        console.error("Sharing failed:", error);
      }
    } else {
      try {
        await navigator.clipboard.writeText(window.location.href);
        setOpen(true);
      } catch (error) {
        console.error("Copy to clipboard failed:", error);
      }
    }
  };

  const handleClose = (
    _event: Event | React.SyntheticEvent<unknown, Event>,
    reason: string
  ) => {
    if (reason === "clickaway") {
      return;
    }
    setOpen(false);
  };

  return (
    <>
      <IconButton onClick={handleClick} disableRipple>
        <IosShareIcon sx={{ width: "22px", height: "22px" }} />
      </IconButton>
      <Snackbar
        open={open}
        autoHideDuration={3000}
        onClose={handleClose}
        message="Link copied to clipboard"
        anchorOrigin={{ vertical: "bottom", horizontal: "center" }}
        sx={{ marginBottom: "50px" }}
      />
    </>
  );
}
