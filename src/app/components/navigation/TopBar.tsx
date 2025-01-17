"use client";

import { Box, Typography } from "@mui/material";
import Link from "next/link";
import { Suspense, useState } from "react";
import NewPostDialog from "../post/new/NewPostDialog";
import NewPostButton from "../post/new/NewPostButton";
import DownloadPrompt from "../pwa/DownloadPrompt";
import BackButton from "./BackButton";
import { User } from "@/db/schema";

type Props = {
  user: User;
};

export default function TopBar({ user }: Readonly<Props>) {
  const [open, setOpen] = useState(false);

  const toggleOpen = () => {
    setOpen((prev) => {
      return !prev;
    });
  };

  return (
    <>
      <Box
        component="header"
        sx={{
          position: "fixed",
          top: 0,
          width: "100%",
          height: "60px",
          zIndex: 1900,
          borderBottom: "0.5px solid rgba(160, 160, 160, 0.3)",
          backdropFilter: "blur(20px)",
          backgroundColor: "rgba(0, 0, 0, 0.33)",
          boxShadow: "0px 2px 4px rgba(0, 0, 0, 0.3)",
        }}
      >
        <Box
          sx={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            height: "100%",
          }}
        >
          <Box
            sx={{
              position: "fixed",
              left: "0px",
            }}
          >
            <BackButton user={user} />
            <Suspense>
              <DownloadPrompt />
            </Suspense>
          </Box>
          <Link href="/">
            <Typography variant="h5" fontWeight={700} sx={{ paddingX: 2 }}>
              Splajompy
            </Typography>
          </Link>
          <Box sx={{ position: "fixed", right: "20px", zIndex: 9000 }}>
            <NewPostButton isOpen={open} toggleOpen={toggleOpen} />
          </Box>
        </Box>
      </Box>
      <NewPostDialog user={user} open={open} toggleOpen={toggleOpen} />
    </>
  );
}
