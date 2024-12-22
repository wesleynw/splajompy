"use server";

import { auth } from "@/auth";
import { db } from "@/db";
import { bios, users } from "@/db/schema";
import { eq } from "drizzle-orm";
import { getUsername } from "./actions";

export async function getUserByUsername(username: string) {
  const results = await db
    .select()
    .from(users)
    .where(eq(users.username, username))
    .limit(1);

  return results[0];
}

export async function getUserBio(user_id: number) {
  console.log(`getting ${await getUsername(user_id)}'s bio`);
  const session = await auth();
  if (!session?.user) {
    return null;
  }

  const results = await db
    .select({ bio: bios.bio })
    .from(bios)
    .where(eq(bios.user_id, user_id))
    .limit(1);

  return results[0] ?? null;
}

export async function setUserBio(user_id: number, bio: string) {
  console.log(`setting ${await getUsername(user_id)}'s bio to '${bio}'`);

  const session = await auth();
  if (!session?.user) {
    return;
  }

  await db
    .insert(bios)
    .values({ user_id: user_id, bio: bio })
    .onConflictDoUpdate({ target: bios.user_id, set: { bio: bio } });
}
