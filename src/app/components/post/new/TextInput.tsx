"use client";

import { Stack } from "@mui/material";
import React, { useState } from "react";
import MentionDialog from "./MentionDialog";
import { toPreviewFormat, toDisplayFormat } from "@/app/utils/mentions";
import { RichTextarea, RichTextareaHandle } from "rich-textarea";

interface TextInputProps {
  value: string;
  setTextValue: React.Dispatch<React.SetStateAction<string>>;
  inputRef: React.RefObject<RichTextareaHandle | null>;
}

export function TextInput({
  value,
  setTextValue,
  inputRef,
}: Readonly<TextInputProps>) {
  const [mentionDialogOpen, setMentionDialogOpen] = useState(false);
  const [mentionedUser, setMentionedUser] = useState("");

  const handleChange = (newValue: string) => {
    setTextValue((prev) => {
      return newValue.replace(/@\S+/g, (match) => {
        const username = match.slice(1);
        const tagMatch = RegExp(new RegExp(`\\{tag:\\d+:${username}\\}`)).exec(
          prev
        );
        return tagMatch ? tagMatch[0] : match;
      });
    });
    const mentionMatch = /@(\w+)$/.exec(newValue);
    setMentionDialogOpen(!!mentionMatch);
    if (mentionMatch) setMentionedUser(mentionMatch[1]);
  };

  return (
    <Stack direction="column" sx={{ width: "100%", position: "relative" }}>
      <RichTextarea
        className="rich-textarea"
        ref={inputRef}
        value={toDisplayFormat(value)}
        onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) =>
          handleChange(e.target.value)
        }
        rows={1}
        autoHeight
        style={{
          width: "100%",
        }}
      >
        {(v: string) => {
          if (v.length === 0) {
            return (
              <span style={{ color: "#AAA" }}>
                Tell us something we&apos;ve never heard before...
              </span>
            );
          }
          return toPreviewFormat(v);
        }}
      </RichTextarea>

      {mentionDialogOpen && (
        <MentionDialog
          mentionedUser={mentionedUser}
          setMentionDialogOpen={setMentionDialogOpen}
          setTextValue={setTextValue}
          inputRef={inputRef}
        />
      )}
    </Stack>
  );
}
