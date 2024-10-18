import { UserWithPassword } from "@/types/user";
import { sql } from "@vercel/postgres";

export async function getUserPWHashFromDb(
  email: string
): Promise<UserWithPassword | null> {
  try {
    const result = await sql<UserWithPassword>`
            SELECT *
            FROM users
            WHERE email = ${email}
            LIMIT 1;
        `;

    return result.rows.length > 0 ? result.rows[0] : null;
  } catch (error) {
    console.error("Database query error:", error);
    throw new Error("Failed to query the database");
  }
}
