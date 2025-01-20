"use server";

import { db } from "@/db";
import { User, users } from "@/db/schema";
import { eq, or } from "drizzle-orm";
import { getCurrentSession } from "../auth/session";

export async function getAllUsers() {
  const { user } = await getCurrentSession();
  if (user === null) {
    return [];
  }

  const results = await db
    .select({ username: users.username, user_id: users.user_id })
    .from(users);

  return results;
}

export async function getUserByUsername(username: string) {
  const results = await db
    .select()
    .from(users)
    .where(eq(users.username, username))
    .limit(1);

  return results[0];
}

export async function getUserByEmail(email: string) {
  const results = await db
    .select()
    .from(users)
    .where(eq(users.email, email))
    .limit(1);

  return results[0];
}

export async function getUserByIdentifier(
  identifier: string
): Promise<User | null> {
  const results = await db
    .select()
    .from(users)
    .where(or(eq(users.email, identifier), eq(users.username, identifier)))
    .limit(1);

  if (results.length > 0) {
    return results[0];
  }

  return null;
}
