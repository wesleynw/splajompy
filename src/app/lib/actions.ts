"use server";

import { signIn } from "@/auth";
import bcrypt from "bcryptjs";
import { registerSchema } from "./zod";
import { sql } from "@vercel/postgres";
import { CredentialsSignin } from "next-auth";
import zod from "zod";
import { redirect } from "next/navigation";

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
  const email = formData.get("email")?.toString() || "";
  const password = formData.get("password")?.toString() || "";

  try {
    const parsedData = registerSchema.parse({ email, password });

    const existingUser = await sql`
      SELECT 1 FROM users WHERE email = ${email};
    `;

    if (existingUser.rows.length > 0) {
      return "A user with this email already exists. Please use a different email.";
    }
    const hashedPassword = await bcrypt.hash(parsedData.password, 10);

    await sql`
      INSERT INTO users (email, password)
      VALUES (${parsedData.email}, ${hashedPassword});
    `;

    await signIn("credentials", {
      redirect: false,
      email: parsedData.email,
      password: parsedData.password,
    });
  } catch (error) {
    if (error instanceof zod.ZodError) {
      return error.errors.map((e) => e.message).join(", ");
    }

    console.error("Registration error:", error);
    return "An error occurred while registering. Please try again.";
  }

  redirect("/");
}
