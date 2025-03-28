"use client";

import { authorize, verifyPasswordlessCode } from "@/app/auth/authentication";
import Image from "next/image";
import { useRouter } from "next/navigation";
import React, { useActionState, useState } from "react";
import logo from "../../apple-icon.png";
import Form from "../base/form/Form";
import Input from "../base/form/Input";
import Button from "../button/Button";
import CenteredLayout from "../layout/CenteredLayout";

const initialState = {
  errors: {},
  payload: undefined,
};

export default function LoginPage() {
  const router = useRouter();
  const [state, dispatch, isPending] = useActionState(authorize, initialState);
  const [otpState, otpDispatch, isOtpPending] = useActionState(
    verifyPasswordlessCode,
    undefined,
  );
  const [identifier, setIdentifier] = useState("");
  const [isUsingPassword, setIsUsingPassword] = useState(false);

  return (
    <div className="mt-16 flex w-screen flex-col justify-center">
      <CenteredLayout>
        {!state.useOtp && (
          <Form action={dispatch}>
            <Image
              width={100}
              height={100}
              src={logo}
              alt="Logo"
              className="mb-7 rounded-3xl shadow-[0_0_15px_5px_rgba(255,255,255,0.3)]"
            />
            <p className="mb-5 text-2xl font-black">Sign in</p>
            <Input
              placeholder="Email or Username"
              type="text"
              name="identifier"
              required
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
            />
            {state.errors?.identifier && (
              <p style={{ color: "red" }}>{state.errors.identifier}</p>
            )}
            {isUsingPassword && (
              <Input
                placeholder="Password"
                type="password"
                name="password"
                required
                defaultValue={(state.payload?.get("password") as string) || ""}
              />
            )}
            {state.errors?.password && (
              <p style={{ color: "red" }}>{state.errors.password}</p>
            )}
            <div className="flex w-full justify-end">
              <button
                className="my-2 text-sm font-bold"
                onClick={() => setIsUsingPassword((prev) => !prev)}
                type="button"
              >
                Sign in with{" "}
                {isUsingPassword ? "username or email" : "password"}
              </button>
            </div>
            <Button fullWidth isLoading={isPending} type="submit">
              Continue
            </Button>
            <div className="mt-2 flex flex-row space-x-2.5">
              <p className="font-bold">New here?</p>
              <button
                className="underline"
                onClick={() => router.push("/register")}
                type="button"
              >
                <p className="font-black">Register</p>
              </button>
            </div>
          </Form>
        )}
        {state.useOtp && (
          <Form action={otpDispatch}>
            <Image
              width={100}
              height={100}
              src={logo}
              alt="Logo"
              className="mb-7 rounded-3xl shadow-[0_0_15px_5px_rgba(255,255,255,0.3)]"
            />
            <p className="mb-4 text-2xl font-black">Check your email</p>
            <p>
              If you have an account, an email has been sent to your email with
              a code.
            </p>
            <input type="hidden" name="identifier" value={identifier} />
            <div className="h-4"></div>
            <Input
              placeholder="Code"
              autoComplete="one-time-code"
              inputMode="numeric"
              pattern="\d{6}"
              maxLength={6}
              name="code"
              required
              className="tracking-widest"
            />
            {otpState?.errors?.code && (
              <p style={{ color: "red" }}>{otpState.errors.code}</p>
            )}
            <Button fullWidth isLoading={isOtpPending} type="submit">
              Continue
            </Button>
          </Form>
        )}
      </CenteredLayout>
    </div>
  );
}
