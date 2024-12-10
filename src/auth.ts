import NextAuth, { DefaultSession } from "next-auth";
import Credentials from "next-auth/providers/credentials";
import { signInSchema } from "./app/lib/zod";
import { getUserPWHashFromDb } from "@/utils/db";
import bcrypt from "bcryptjs";
import zod from "zod";

declare module "next-auth" {
  interface Session {
    user: {
      user_id: number;
      username: string;
    } & DefaultSession["user"];
  }

  interface User {
    user_id: number;
    username: string;
  }
}

export const { handlers, signIn, signOut, auth } = NextAuth({
  providers: [
    Credentials({
      credentials: {
        identifier: {},
        password: {},
      },
      authorize: async (credentials) => {
        try {
          const { identifier, password } = await signInSchema.parseAsync(
            credentials
          );

          console.log("identifier", identifier);

          const user = await getUserPWHashFromDb(identifier);

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
  callbacks: {
    jwt({ token, user }) {
      if (user) {
        token.user_id = user.user_id;
        token.username = user.username;
      }
      return token;
    },
    session({ session, token }) {
      session.user.user_id = token.user_id;
      session.user.username = token.username;
      return session;
    },
  },
});

import {} from "next-auth/jwt";

declare module "next-auth/jwt" {
  interface JWT {
    user_id: number;
    username: string;
  }
}
