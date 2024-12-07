import dayjs from "dayjs";
import relativeTime from "dayjs/plugin/relativeTime";
import utc from "dayjs/plugin/utc";
import timezone from "dayjs/plugin/timezone";
import { auth } from "@/auth";
import { db } from "@/db";
import { posts, users } from "@/db/schema";
import { eq } from "drizzle-orm";
import { redirect } from "next/navigation";
import { Metadata } from "next";
import { SessionProvider } from "next-auth/react";
import Navigation from "@/app/components/navigation/Navigation";
import { PostProvider } from "@/app/data/PostProvider";
import PostPageContent from "@/app/components/post/SinglePagePost";

dayjs.extend(relativeTime);
dayjs.extend(utc);
dayjs.extend(timezone);

type Props = {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
};

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const id = Number((await params).id);

  const post = await db
    .select({ username: users.username, text: posts.text })
    .from(posts)
    .where(eq(posts.post_id, id))
    .innerJoin(users, eq(posts.user_id, users.user_id))
    .limit(1);

  if (post.length === 0) {
    return {
      title: "Post not found",
      description: "This post cannot be found.",
    };
  }

  return {
    title: `${post[0].username}: ${post[0].text ?? "Image"}`,
    description: post[0].text ?? "",
  };
}

export default async function Page({
  params,
}: Readonly<{
  params: Promise<{ id: number }>;
}>) {
  const session = await auth();
  if (!session) {
    redirect("/login");
  }
  const id = (await params).id;

  return (
    <>
      <SessionProvider session={session}>
        <PostProvider post_id={id}>
          <PostPageContent />
        </PostProvider>
      </SessionProvider>
      <Navigation session={session} />
    </>
  );
}
