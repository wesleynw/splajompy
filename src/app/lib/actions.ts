"use server";

import { auth, signIn } from "@/auth";
import bcrypt from "bcryptjs";
import { postTextSchema, registerSchema } from "./zod";
import { sql } from "@vercel/postgres";
import { CredentialsSignin } from "next-auth";
import zod from "zod";
import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";

export async function authenticate(_currentState: unknown, formData: FormData) {
  try {
    await signIn("credentials", formData);
  } catch (err) {
    if (err instanceof CredentialsSignin) {
      switch (err.type) {
        case "CredentialsSignin":
          return "Invalid credentials";
        default:
          return "Something went wrong.";
      }
    }
  }
  redirect("/");
}

export async function register(_currentState: unknown, formData: FormData) {
  const username = formData.get("username")?.toString() || "";
  const email = formData.get("email")?.toString() || "";
  const password = formData.get("password")?.toString() || "";

  try {
    const parsedData = registerSchema.parse({ username, email, password });

    const existingUser = await sql`
      SELECT 1 FROM users WHERE email = ${email} OR username = ${username} LIMIT 1;
    `;

    if (existingUser.rows.length > 0) {
      return "A user with this email or username already exists. Please use a different email.";
    }
    const hashedPassword = await bcrypt.hash(parsedData.password, 10);

    await sql`
      INSERT INTO users (email, password, username)
      VALUES (${parsedData.email}, ${hashedPassword}, ${parsedData.username});
    `;

    await signIn("credentials", {
      redirect: false,
      email: parsedData.email,
      password: parsedData.password,
      username: parsedData.username,
    });
  } catch (error) {
    if (error instanceof zod.ZodError) {
      return error.errors.map((e) => e.message).join(", ");
    }

    return "An error occurred while registering. Please try again.";
  }

  redirect("/");
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

  if (postText) {
    await sql`
    INSERT INTO posts (user_id, text)
    VALUES (${session?.user?.id}, ${sanitizedPostText})
  `;
    revalidatePath("/");
    formData.set("text", "");
  }
}
