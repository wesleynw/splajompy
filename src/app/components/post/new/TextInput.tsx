"use client";

import theme from "@/theme";
import { TextField } from "@mui/material";

interface TextInputProps {
  value: string;
  onChange: (event: React.ChangeEvent<HTMLInputElement>) => void;
  inputRef: React.RefObject<HTMLInputElement | null>;
}

export function TextInput({
  value,
  onChange,
  inputRef,
}: Readonly<TextInputProps>) {
  return (
    <TextField
      inputRef={inputRef}
      value={value}
      onChange={onChange}
      name="text"
      variant="outlined"
      placeholder="What's on your mind?"
      fullWidth
      multiline
      sx={{
        "& .MuiOutlinedInput-root": {
          borderRadius: "12px",
          backgroundColor: "#f5f5f5",
          color: "#333333",
          "& fieldset": {
            borderColor: "#4a90e2",
          },
          "&:hover fieldset": {
            borderColor: "#357abf",
          },
          ...theme.applyStyles("dark", {
            backgroundColor: "#2b2b2b",
            color: "#e0e0e0",
          }),
        },
        "& .MuiInputBase-input": {
          color: "#333333",
          ...theme.applyStyles("dark", { color: "#e0e0e0" }),
        },
      }}
    />
  );
}
