"use server";

import { db } from "@/db";
import { comments, images, notifications, users } from "@/db/schema";
import { eq, asc } from "drizzle-orm";
import { revalidatePath } from "next/cache";
import { getCurrentSession } from "../auth/session";

export async function insertImage(
  post_id: number,
  imageBlobUrl: string,
  width: number,
  height: number
) {
  await db.insert(images).values({
    post_id: post_id,
    height: height,
    width: width,
    imageBlobUrl: imageBlobUrl,
  });

  revalidatePath("/");
}

export async function insertComment(
  text: string,
  post_id: number,
  poster: number
) {
  const { user } = await getCurrentSession();
  if (user === null) {
    return;
  }

  if (text) {
    const comment = await db
      .insert(comments)
      .values({
        post_id: Number(post_id),
        user_id: user.user_id,
        text: text,
      })
      .returning();

    const result = await db
      .select()
      .from(comments)
      .innerJoin(users, eq(comments.user_id, users.user_id))
      .where(eq(comments.comment_id, comment[0].comment_id))
      .limit(1);

    if (poster !== user.user_id) {
      await db.insert(notifications).values({
        user_id: poster,
        message: `@${user.username} commented on your post`,
        link: `/post/${post_id}`,
      });
    }

    return result;
  }
}

export async function getComments(post_id: number) {
  const results = await db
    .select()
    .from(comments)
    .innerJoin(users, eq(comments.user_id, users.user_id))
    .where(eq(comments.post_id, post_id))
    .orderBy(asc(comments.comment_date));

  return results;
}

export async function getUsername(user_id: number) {
  const results = await db
    .select()
    .from(users)
    .where(eq(users.user_id, user_id))
    .limit(1);

  return results[0].username;
}
