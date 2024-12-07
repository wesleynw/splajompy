"use client";

import { Box, CircularProgress, Typography } from "@mui/material";
import NewPost from "../post/NewPost/NewPost";
import EmptyFeed from "./EmptyFeed";
import { FeedType, PostType, useFeed } from "../../data/FeedProvider";
import { SessionProvider, signOut } from "next-auth/react";
import { Session } from "next-auth";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import Post from "../post/Post";

export type Props = {
  session: Session;
  feedType: FeedType;
  ofUser?: number;
  showNewPost: boolean;
};

export default function Feed({
  session,
  feedType,
  ofUser,
  showNewPost,
}: Readonly<Props>) {
  const router = useRouter();
  const observerRef = useRef<HTMLDivElement>(null);
  const [offset, setOffset] = useState(0);

  const {
    getHomePosts,
    getAllPosts,
    getProfilePosts,
    loading,
    error,
    checkMorePostsToFetch,
    fetchPosts,
    updatePost,
    insertPostToFeed,
    deletePostFromFeed,
  } = useFeed();

  const user = feedType === "profile" ? ofUser : session.user.user_id;

  useEffect(() => {
    fetchPosts(feedType, 0, user);
    setOffset(10);
  }, [fetchPosts, feedType, user, session]);

  useEffect(() => {
    if (!session.user.username) {
      signOut();
      router.push("/login");
    }

    if (loading || !checkMorePostsToFetch(feedType) || !observerRef.current) {
      return;
    }

    const currentObserverRef = observerRef.current;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && !loading) {
          fetchPosts(feedType, offset, user);
          setOffset(offset + 10);
        }
      },
      { root: null, rootMargin: "200px", threshold: 0 }
    );

    if (currentObserverRef) {
      observer.observe(currentObserverRef);
    }

    return () => {
      if (currentObserverRef) {
        observer.unobserve(currentObserverRef);
      }
    };
  }, [
    router,
    fetchPosts,
    feedType,
    session.user.username,
    session.user.user_id,
    loading,
    offset,
    checkMorePostsToFetch,
    user,
  ]);

  if (error) {
    return (
      <Box
        display="flex"
        justifyContent="center"
        alignItems="center"
        width="100%"
        height="30vh"
      >
        <div>Something went wrong. Please try again later.</div>
      </Box>
    );
  }

  let currentPosts;
  switch (feedType) {
    case "home":
      currentPosts = getHomePosts();
      break;
    case "all":
      currentPosts = getAllPosts();
      break;
    case "profile":
      currentPosts = getProfilePosts();
      break;
    default:
      throw new Error("Invalid feed type");
  }

  const isOnlyCurrentUsersPosts = currentPosts.every(
    (post) => post.user_id === session.user.user_id
  );

  return (
    <Box
      sx={{
        marginBottom: "60px",
        px: { xs: 2, md: 4 },
        width: "100%",
      }}
    >
      <SessionProvider session={session}>
        {showNewPost && (
          <NewPost
            insertPostToFeed={(post) => insertPostToFeed(feedType, post)}
          />
        )}
        {isOnlyCurrentUsersPosts && feedType == "home" && (
          <EmptyFeed loading={loading} />
        )}
        {currentPosts.map((post) => (
          <Post
            key={post.post_id}
            id={post.post_id}
            date={new Date(post.postdate + "Z")}
            user_id={post.user_id}
            poster={post.poster}
            imageHeight={post.imageHeight}
            imageWidth={post.imageWidth}
            content={post.text}
            imagePath={post.imageBlobUrl}
            comment_count={post.comment_count}
            likedByCurrentUser={post.liked}
            updateParentContext={(updatedAttributes: Partial<PostType>) => {
              updatePost(post.post_id, updatedAttributes);
            }}
            onDelete={() => deletePostFromFeed(feedType, post.post_id)}
          />
        ))}
        <div ref={observerRef} style={{ height: "1px" }} />
        {loading && (
          <Box
            display="flex"
            justifyContent="center"
            alignItems="center"
            width="100%"
            height="30vh"
          >
            <CircularProgress />
          </Box>
        )}
        {currentPosts.length > 0 &&
          !checkMorePostsToFetch(feedType) &&
          feedType === "all" && (
            <Box
              display="flex"
              justifyContent="center"
              alignItems="center"
              margin="0 auto"
              width="100%"
              maxWidth="600px"
              height="30vh"
            >
              <Typography
                variant="h6"
                sx={{
                  textAlign: "center",
                  color: "#777777",
                  paddingBottom: 2,
                }}
              >
                Is that the very first post? <br />
                What came before that? <br />
                Nothing at all? <br />
                It always just{" "}
                <Box fontWeight="800" display="inline">
                  Splajompy
                </Box>
                .
              </Typography>
            </Box>
          )}
      </SessionProvider>
    </Box>
  );
}
