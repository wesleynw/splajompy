"use client";

import React from "react";
import { Box, Typography, Stack, Button } from "@mui/material";
import BackButton from "../navigation/BackButton";
import { signOut } from "next-auth/react";
import FollowButton from "../follows/FollowButton";
import Feed from "../feed/Feed";
import theme from "@/theme";
import { Session } from "next-auth";
import Bio from "./Bio";

interface Props {
  session: Session;
  user: {
    user_id: number;
    email: string;
    password: string;
    username: string;
  };
}

export default function UserView({ session, user }: Readonly<Props>) {
  const isOwnProfile = session.user.user_id === user.user_id;

  return (
    <Box>
      <Box sx={{ px: { xs: 2, md: 4 } }}>
        <Box
          sx={{
            width: "100%",
            maxWidth: 600,
            borderRadius: "8px",
            gap: 1,
            padding: 3,
            background: "linear-gradient(135deg, #ffffff, #f9f9f9)",
            boxShadow: "0 2px 8px rgba(0, 0, 0, 0.1)",
            margin: "10px auto",
            ...theme.applyStyles("dark", {
              background: "linear-gradient(135deg, #1b1b1b, #2a2a2a)",
              boxShadow: "0 2px 8px rgba(0, 0, 0, 0.5)",
            }),
          }}
        >
          <Box display="flex" justifyContent="space-between">
            <BackButton />
            {isOwnProfile && (
              <Button
                variant="contained"
                size="medium"
                onClick={() => {
                  signOut({ redirectTo: "/login" });
                }}
                sx={{
                  textTransform: "none",
                  borderRadius: "20px",
                  paddingX: 2,
                  paddingY: 0.5,
                  fontWeight: "bold",
                  fontSize: "0.875rem",
                  minWidth: "auto",
                  backgroundColor: "#1DA1F2",
                  color: "#ffffff",
                  ...theme.applyStyles("dark", {
                    backgroundColor: "#1DA1F2",
                  }),
                  "&:hover": {
                    backgroundColor: "#0d8de6",
                  },
                }}
              >
                Sign Out
              </Button>
            )}
            <FollowButton user_id={user.user_id} show_unfollow={true} />
          </Box>
          <Stack
            direction="column"
            alignItems="left"
            justifyContent="space-between"
            marginTop={1}
            spacing={3}
          >
            <Typography
              variant="h6"
              sx={{
                fontWeight: "bold",
                color: "#333333",
                wordBreak: "break-all",
                marginLeft: 1,
                ...theme.applyStyles("dark", { color: "#ffffff" }),
              }}
            >
              @{user.username}
            </Typography>
            <Bio isOwnProfile={isOwnProfile} user={user} />
          </Stack>
        </Box>
      </Box>
      <Box>
        <Feed session={session} page="profile" user_id={user.user_id} />
      </Box>
    </Box>
  );
}
