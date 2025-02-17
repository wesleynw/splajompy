"use client";

import { toDisplayFormat, toPreviewFormat } from "@/app/utils/mentions";
import { Stack } from "@mui/material";
import React, { useState } from "react";
import { RichTextarea, RichTextareaHandle } from "rich-textarea";
import MentionDialog from "./MentionDialog";
import WordLimitCircularProgress from "./WordLimitCircularProgress";

interface TextInputProps {
  placeholder: string;
  value: string;
  setTextValue: React.Dispatch<React.SetStateAction<string>>;
  inputRef?: React.RefObject<RichTextareaHandle | null>;
}

const MAX_LENGTH = 250;
export function TextInput({
  placeholder,
  value,
  setTextValue,
  inputRef,
}: Readonly<TextInputProps>) {
  const [mentionDialogOpen, setMentionDialogOpen] = useState(false);
  const [mentionedUser, setMentionedUser] = useState("");
  const [textLimit, setTextLimit] = useState(0);

  const handleChange = (newValue: string) => {
    const wordCount = newValue.trim().split(/\s+/).length;
    setTextLimit((wordCount / MAX_LENGTH) * 100);

    setTextValue((prev) => {
      return newValue.replace(/@\S+/g, (match) => {
        const username = match.slice(1);
        const tagMatch = RegExp(new RegExp(`\\{tag:\\d+:${username}\\}`)).exec(
          prev,
        );
        return tagMatch ? tagMatch[0] : match;
      });
    });
    const mentionMatch = /@(\w+)$/.exec(newValue);
    setMentionDialogOpen(!!mentionMatch);
    if (mentionMatch) setMentionedUser(mentionMatch[1]);
  };

  return (
    <Stack
      direction="column"
      spacing={1}
      sx={{ width: "100%", position: "relative", alignItems: "flex-end" }}
    >
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
            return <span style={{ color: "#AAA" }}>{placeholder}</span>;
          }
          return toPreviewFormat(v);
        }}
      </RichTextarea>
      <WordLimitCircularProgress progressPercentage={textLimit} />

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
