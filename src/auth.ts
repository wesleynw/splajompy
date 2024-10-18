import NextAuth from "next-auth";
import Credentials from "next-auth/providers/credentials";
import { signInSchema } from "./app/lib/zod";
import { getUserPWHashFromDb } from "@/utils/db";
import bcrypt from "bcryptjs";
import { User } from "./types/user";
import zod from "zod";

export const { handlers, signIn, signOut, auth } = NextAuth({
  providers: [
    Credentials({
      credentials: {
        email: {},
        password: {},
      },
      authorize: async (credentials): Promise<User | null> => {
        try {
          const { email, password } = await signInSchema.parseAsync(
            credentials
          );

          const user = await getUserPWHashFromDb(email);

          if (user != null) {
            const match = await bcrypt.compare(password, user.password);

            if (!match) {
              throw new Error("Incorrect password!");
            }
            return user;
          }
          throw new Error("User not found!");
        } catch (err) {
          if (err instanceof zod.ZodError) {
            return null;
          }
        }
        return null;
      },
    }),
  ],
});
