"use client";

import { authenticate } from "@/app/lib/actions";
import Link from "next/link";
import { useFormState, useFormStatus } from "react-dom";

export default function Page() {
  const [errorMessage, dispatch] = useFormState(authenticate, undefined);

  return (
    <>
      <form action={dispatch}>
        <input
          type="text"
          name="email"
          placeholder="Email or Username"
          required
        />
        <input
          type="password"
          name="password"
          placeholder="Password"
          required
        />
        <div>{errorMessage && <p>{errorMessage}</p>}</div>
        <LoginButton />
      </form>
      <Link href="/register">Register</Link>
    </>
  );
}

function LoginButton() {
  const { pending } = useFormStatus();

  return (
    <button aria-disabled={pending} type="submit">
      Login
    </button>
  );
}
