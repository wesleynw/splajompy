import { UserWithPassword } from "@/types/user";
import { sql } from "@vercel/postgres";

export async function getUserPWHashFromDb(
  email: string,
  username: string
): Promise<UserWithPassword | null> {
  try {
    const result = await sql<UserWithPassword>`
            SELECT *
            FROM users
            WHERE email = ${email} OR username = ${username}
            LIMIT 1;
        `;

    return result.rows.length > 0 ? result.rows[0] : null;
  } catch {
    throw new Error("Failed to query the database");
  }
}
