import NextAuth from "next-auth";
import Credentials from "next-auth/providers/credentials";
import { signInSchema } from "./app/lib/zod";
import { getUserPWHashFromDb } from "@/utils/db";
import bcrypt from "bcryptjs";
import zod from "zod";

export const { handlers, signIn, signOut, auth } = NextAuth({
  providers: [
    Credentials({
      credentials: {
        username: {},
        email: {},
        password: {},
      },
      authorize: async (credentials) => {
        try {
          const { email, password, username } = await signInSchema.parseAsync(
            credentials
          );

          const user = await getUserPWHashFromDb(email, username);

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
        token.id = user.id ?? "";
      }
      return token;
    },
    session({ session, token }) {
      session.user.id = token.id;
      return session;
    },
  },
});

// The `JWT` interface can be found in the `next-auth/jwt` submodule
import {} from "next-auth/jwt";

declare module "next-auth/jwt" {
  /** Returned by the `jwt` callback and `auth`, when using JWT sessions */
  interface JWT {
    /** OpenID ID Token */
    id: string; // Add the id property to the JWT interface
  }
}
