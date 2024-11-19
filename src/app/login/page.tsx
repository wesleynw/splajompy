"use client";

import { Stack } from "@mui/material";
import { authenticate } from "@/app/lib/actions";
import { useFormState } from "react-dom";
import LoginCard from "../components/login/LoginCard";

export default function Page() {
  const [errorMessage, dispatch] = useFormState(authenticate, undefined);

  return (
    <Stack
      justifyContent="center"
      alignItems="center"
      sx={{
        backgroundColor: "grey",
        height: "100vh",
      }}
    >
      <LoginCard dispatch={dispatch} errorMessage={errorMessage} />
    </Stack>
  );
}
