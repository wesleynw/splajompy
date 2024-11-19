import {
  Card,
  Stack,
  TextField,
  Button,
  Divider,
  styled,
  Typography,
  FormHelperText,
} from "@mui/material";
import Link from "next/link";
import theme from "@/theme";
import { useFormStatus } from "react-dom";

function LoginButton() {
  const { pending } = useFormStatus();

  return (
    <Button aria-disabled={pending} type="submit">
      Login
    </Button>
  );
}

// constant StyledTextField = styled(TextField)(() => ({
// // here
// }))

function LoginInput({
  name,
  id,
  label,
}: {
  name: string;
  id: string;
  label: string;
}) {
  return (
    <TextField
      required
      name={name}
      id={id}
      label={label}
      variant="standard"
      size="small"
      sx={{ width: "60%" }}
    />
  );
}

export default function LoginCard({
  dispatch,
  errorMessage,
}: {
  dispatch: (payload: FormData) => void;
  errorMessage: string | undefined;
}) {
  return (
    <form action={dispatch}>
      <Stack
        component={Card}
        alignItems="center"
        justifyContent="center"
        spacing={2}
        sx={{
          height: "50vh",
          width: "50vw",
          backgroundColor: theme.palette.background.default,
        }}
      >
        <Typography sx={{ fontSize: 24 }}>Welcome</Typography>
        <LoginInput
          name="identifier"
          id="login-email-username-input"
          label="Email or Username"
        />
        {/* TODO: make password not visible when typing */}
        <LoginInput
          name="password"
          id="login-password-input"
          label="Password"
        />
        {/* TODO: make link to register visible */}
        <FormHelperText>
          {`Not a member? `}
          <Link href="/register">Register</Link>
        </FormHelperText>
        <div>{errorMessage && <p>{errorMessage}</p>}</div>
        <LoginButton />
      </Stack>
    </form>
  );
}
