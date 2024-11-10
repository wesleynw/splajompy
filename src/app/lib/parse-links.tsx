import React from "react";
import Link from "@mui/material/Link";

export function parseLinks(text: string) {
  const urlRegex = /(https?:\/\/[^\s]+)/g;

  return text.split(urlRegex).map((part, index) => {
    if (urlRegex.test(part)) {
      return (
        <Link
          key={index}
          href={part}
          target="_blank"
          rel="noopener noreferrer"
          onClick={(event) => event.stopPropagation()} // stop event bubbling
          sx={{
            color: "lightblue",
            textDecoration: "underline",
          }}
        >
          {part}
        </Link>
      );
    }
    return part;
  });
}
