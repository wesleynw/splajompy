import { auth } from "@/auth";
import Post from "./post/Post";
import { Box } from "@mui/material";
import { getAllPosts } from "../lib/actions";

export default async function Page() {
  const session = await auth();
  if (!session) {
    return <></>;
  }

  const results = await getAllPosts();

  return (
    <Box>
      {results.map((post) => (
        <Post
          key={post.post_id}
          id={post.post_id}
          date={new Date(post.postdate + "Z")} // + "Z" to convert to UTC
          content={post.text}
          poster={post.poster}
          comment_count={post.comment_count}
          link={post.link}
        />
      ))}
    </Box>
  );
}
