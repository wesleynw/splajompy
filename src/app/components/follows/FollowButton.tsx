"use client";

import { useSession } from "next-auth/react";
import { useState, useEffect } from "react";
import { followUser, isFollowingUser, unfollowUser } from "@/app/lib/follows";
import { Button } from "@mui/material";
import theme from "@/theme";

type Props = {
  user_id: number;
  show_unfollow: boolean;
};

export default function FollowButton({
  user_id,
  show_unfollow,
}: Readonly<Props>) {
  const [hasFollowed, setHasFollowed] = useState(false);
  const { data: session } = useSession();
  const [isFollowing, setIsFollowing] = useState<boolean | null>(null);
  const [loading, setLoading] = useState(false);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    const checkFollowingStatus = async () => {
      if (session) {
        const result = await isFollowingUser(user_id);
        setIsFollowing(result);
        setIsLoaded(true);
      }
    };
    checkFollowingStatus();
  }, [session, user_id]);

  if (
    !session ||
    (isLoaded && isFollowing === null) ||
    (!show_unfollow && isFollowing && !hasFollowed)
  ) {
    return null;
  }

  const handleFollow = async (event: React.MouseEvent) => {
    event.preventDefault();
    setLoading(true);
    try {
      if (isFollowing) {
        await unfollowUser(user_id);
        setIsFollowing(false);
      } else {
        await followUser(user_id);
        setIsFollowing(true);
        setHasFollowed(true);
      }
    } catch (error) {
      console.error("Failed to update follow status:", error);
    } finally {
      setLoading(false);
    }
  };

  if (!isLoaded) {
    return null;
  }

  return (
    <Button
      variant="contained"
      size="medium"
      onClick={handleFollow}
      disabled={loading}
      sx={{
        textTransform: "none",
        borderRadius: "20px",
        paddingX: 2,
        paddingY: 0.5,
        fontWeight: "bold",
        fontSize: "0.875rem",
        minWidth: "auto",
        color: "#ffffff",
        backgroundColor: theme.palette.secondary.main,
        "&:hover": {
          backgroundColor: "#0d8de6",
        },
      }}
    >
      {isFollowing ? "Unfollow" : "Follow"}
    </Button>
  );
}
