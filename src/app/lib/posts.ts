"use server";

import { db } from "@/db";
import {
  comments,
  follows,
  images,
  likes,
  notifications,
  posts,
  users,
} from "@/db/schema";
import { and, or, count, desc, eq, exists, sql } from "drizzle-orm";
import { deleteObject } from "./s3";
import { getCurrentSession } from "../auth/session";
import { internalTagRegex } from "../utils/mentions";

export type PostData = {
  post_id: number;
  text: string | null;
  postdate: string;
  user_id: number;
  poster: string;
  comment_count: number;
  imageBlobUrl: string | null;
  imageWidth: number | null;
  imageHeight: number | null;
};

const FETCH_LIMIT = 10;

export async function insertPost(text: string) {
  const { user } = await getCurrentSession();
  if (user === null) {
    return;
  }

  const post = await db
    .insert(posts)
    .values({
      user_id: Number(user.user_id),
      text: text,
    })
    .returning();

  for (const tag of text.matchAll(internalTagRegex)) {
    const user_id = Number(tag[1]);
    if (user.user_id !== user_id) {
      await db.insert(notifications).values({
        user_id: user_id,
        message: `@${user.username} mentioned you in a post`,
        link: `/post/${post[0].post_id}`,
      });
    }
  }
  return post[0];
}

export async function getAllPostsFromDb(offset: number) {
  const { user } = await getCurrentSession();
  if (user === null) {
    return [];
  }

  const results = await db
    .select({
      post_id: posts.post_id,
      text: posts.text,
      postdate: posts.postdate,
      user_id: users.user_id,
      poster: users.username,
      comment_count: sql<number>`COUNT(DISTINCT ${comments.comment_id})`,
      imageBlobUrl: images.imageBlobUrl,
      imageWidth: images.width,
      imageHeight: images.height,
      liked: sql<boolean>`
        EXISTS (
          SELECT 1
          FROM ${likes}
          WHERE ${likes.post_id} = ${posts.post_id}
            AND ${likes.user_id} = ${user.user_id}
        )
      `,
    })
    .from(posts)
    .innerJoin(users, eq(posts.user_id, users.user_id))
    .leftJoin(comments, eq(posts.post_id, comments.post_id))
    .leftJoin(images, eq(posts.post_id, images.post_id))
    .groupBy(
      posts.post_id,
      users.user_id,
      images.imageBlobUrl,
      images.width,
      images.height
    )
    .orderBy(desc(posts.postdate))
    .limit(FETCH_LIMIT)
    .offset(offset);

  return results;
}

export async function getAllPostsForFollowing(offset: number) {
  const { user } = await getCurrentSession();
  if (user === null) {
    return [];
  }

  const user_id = user.user_id;

  const results = await db
    .select({
      post_id: posts.post_id,
      text: posts.text,
      postdate: posts.postdate,
      user_id: users.user_id,
      poster: users.username,
      comment_count: sql<number>`COUNT(DISTINCT ${comments.comment_id})`,
      imageBlobUrl: images.imageBlobUrl,
      imageWidth: images.width,
      imageHeight: images.height,
      liked: sql<boolean>`
      EXISTS (
        SELECT 1
        FROM ${likes}
        WHERE ${likes.post_id} = ${posts.post_id}
          AND ${likes.user_id} = ${user_id}
      )
    `,
    })
    .from(posts)
    .innerJoin(users, eq(posts.user_id, users.user_id))
    .leftJoin(comments, eq(posts.post_id, comments.post_id))
    .leftJoin(images, eq(posts.post_id, images.post_id))
    .leftJoin(likes, eq(posts.post_id, likes.post_id))
    .where(
      or(
        eq(posts.user_id, user_id),
        exists(
          db
            .select()
            .from(follows)
            .where(
              and(
                eq(follows.follower_id, user_id),
                eq(follows.following_id, posts.user_id)
              )
            )
        )
      )
    )
    .groupBy(
      posts.post_id,
      users.user_id,
      images.imageBlobUrl,
      images.width,
      images.height
    )
    .orderBy(desc(posts.postdate))
    .limit(FETCH_LIMIT)
    .offset(offset);

  return results;
}

export async function getPostsByUserId(offset: number, user_id: number) {
  const { user } = await getCurrentSession();
  if (user === null) {
    return [];
  }

  const results = await db
    .select({
      post_id: posts.post_id,
      text: posts.text,
      postdate: posts.postdate,
      user_id: users.user_id,
      poster: users.username,
      comment_count: count(comments.comment_id),
      imageBlobUrl: images.imageBlobUrl,
      imageWidth: images.width,
      imageHeight: images.height,
      liked: sql<boolean>`
      EXISTS (
        SELECT 1
        FROM ${likes}
        WHERE ${likes.post_id} = ${posts.post_id}
          AND ${likes.user_id} = ${user.user_id}
      )
    `,
    })
    .from(posts)
    .innerJoin(users, eq(posts.user_id, users.user_id))
    .leftJoin(comments, eq(posts.post_id, comments.post_id))
    .leftJoin(images, eq(posts.post_id, images.post_id))
    .where(eq(users.user_id, user_id))
    .groupBy(
      posts.post_id,
      users.user_id,
      images.imageBlobUrl,
      images.width,
      images.height
    )
    .orderBy(desc(posts.postdate))
    .limit(FETCH_LIMIT)
    .offset(offset);

  return results;
}

export async function getPost(post_id: number) {
  const { user } = await getCurrentSession();
  if (user === null) {
    return;
  }

  const results = await db
    .select({
      post_id: posts.post_id,
      text: posts.text,
      postdate: posts.postdate,
      user_id: users.user_id,
      poster: users.username,
      comment_count: count(comments.comment_id),
      imageBlobUrl: images.imageBlobUrl,
      imageWidth: images.width,
      imageHeight: images.height,
      liked: sql<boolean>`
      EXISTS (
        SELECT 1
        FROM ${likes}
        WHERE ${likes.post_id} = ${posts.post_id}
          AND ${likes.user_id} = ${user.user_id}
      )
    `,
    })
    .from(posts)
    .innerJoin(users, eq(posts.user_id, users.user_id))
    .leftJoin(comments, eq(posts.post_id, comments.post_id))
    .leftJoin(images, eq(posts.post_id, images.post_id))
    .where(eq(posts.post_id, post_id))
    .groupBy(
      posts.post_id,
      users.user_id,
      images.imageBlobUrl,
      images.width,
      images.height
    );

  return results[0];
}

export async function deletePost(post_id: number) {
  const { user } = await getCurrentSession();
  if (user === null) {
    return;
  }

  await deleteObject(post_id);

  await db
    .delete(posts)
    .where(and(eq(posts.user_id, user.user_id), eq(posts.post_id, post_id)));
}
