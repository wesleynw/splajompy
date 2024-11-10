"use server";

import { auth, signIn } from "@/auth";
import bcrypt from "bcryptjs";
import { postTextSchema, registerSchema } from "./zod";
import { CredentialsSignin } from "next-auth";
import zod from "zod";
import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { db } from "@/db";
import { comments, posts, users } from "@/db/schema";
import { count, desc, eq, or } from "drizzle-orm";

export async function authenticate(_currentState: unknown, formData: FormData) {
  try {
    await signIn("credentials", formData);
  } catch (err) {
    if (err instanceof CredentialsSignin) {
      if (err.type === "CredentialsSignin") {
        return "Invalid credentials";
      } else {
        return "Something went wrong.";
      }
    }
  }
  redirect("/");
}

export async function register(_currentState: unknown, formData: FormData) {
  const username = formData.get("username")?.toString() ?? "";
  const email = formData.get("email")?.toString() ?? "";
  const password = formData.get("password")?.toString() ?? "";

  try {
    const parsedData = registerSchema.parse({ username, email, password });

    const existingUser = await db
      .select()
      .from(users)
      .where(or(eq(users.email, email), eq(users.username, username)))
      .limit(1);

    if (existingUser.length > 0) {
      return "A user with this email or username already exists. Please use a different email.";
    }
    const hashedPassword = await bcrypt.hash(parsedData.password, 10);

    await db.insert(users).values({
      email: parsedData.email,
      password: hashedPassword,
      username: parsedData.username,
    });

    await signIn("credentials", {
      redirect: false,
      identifier: parsedData.email,
      password: parsedData.password,
    });
  } catch (error) {
    if (error instanceof zod.ZodError) {
      return error.errors.map((e) => e.message).join(", ");
    }

    return "An error occurred while registering. Please try again.";
  }

  redirect("/");
}

export async function getAllPosts() {
  const results = await db
    .select({
      post_id: posts.post_id,
      text: posts.text,
      postdate: posts.postdate,
      poster: users.username,
      comment_count: count(comments.comment_id),
      link: posts.link,
    })
    .from(posts)
    .innerJoin(users, eq(posts.user_id, users.user_id))
    .leftJoin(comments, eq(posts.post_id, comments.post_id))
    .groupBy(posts.post_id, users.user_id)
    .orderBy(desc(posts.postdate));

  return results;
}

export async function insertPost(formData: FormData) {
  "use server";
  const session = await auth();
  if (!session) {
    return;
  }

  const postText = formData.get("text")?.toString();

  const parsed = postTextSchema.safeParse({ text: postText });
  if (!parsed.success) {
    return;
  }

  const sanitizedPostText = parsed.data.text;

  const urlRegex = /(https?:\/\/[^\s]+)/g;
  const link = sanitizedPostText.match(urlRegex)?.[0] ?? null;

  if (postText) {
    await db.insert(posts).values({
      user_id: Number(session?.user?.user_id),
      text: sanitizedPostText,
      link: link,
    });

    revalidatePath("/");
    formData.set("text", "");
  }
}

export async function insertComment(text: string, post_id: number) {
  "use server";
  const session = await auth();
  if (!session) {
    return;
  }

  const parsed = postTextSchema.safeParse({ text: text });
  if (!parsed.success) {
    return;
  }

  const sanitizedCommentText = parsed.data.text;

  if (text) {
    const comment = await db
      .insert(comments)
      .values({
        post_id: Number(post_id),
        user_id: session?.user?.user_id,
        text: sanitizedCommentText,
      })
      .returning();

    return await db
      .select()
      .from(comments)
      .innerJoin(users, eq(comments.user_id, users.user_id))
      .where(eq(comments.comment_id, comment[0].comment_id))
      .limit(1);
  }
}

export async function getComments(post_id: number) {
  const results = await db
    .select()
    .from(comments)
    .innerJoin(users, eq(comments.user_id, users.user_id))
    .where(eq(comments.post_id, post_id));

  return results;
}
