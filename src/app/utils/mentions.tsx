import Link from "next/link";

export const internalTagRegex = /\{tag:(\d+):(.+?)\}/g;

export const toDisplayFormat = (text: string): string => {
  return text.replace(internalTagRegex, (_match, _p1, p2) => "@" + p2);
};

export const toPreviewFormat = (text: string): React.ReactNode => {
  const mentionRegex = /(@\S+)/g;
  return text.split(mentionRegex).map((part, index) =>
    mentionRegex.test(part) ? (
      <span
        key={`${part}-${index}`}
        style={{
          backgroundColor: "rgba(53, 122, 191, 0.5)",
          borderRadius: "3px",
        }}
      >
        {part}
      </span>
    ) : (
      part
    )
  );
};

export const renderMentions = (text: string): React.ReactNode => {
  const parts: React.ReactNode[] = [];
  let lastIndex = 0;

  text.replace(internalTagRegex, (match, userId, username, offset) => {
    if (offset > lastIndex) {
      parts.push(text.slice(lastIndex, offset));
    }
    parts.push(
      <Link key={offset} href={`/user/${username}`}>
        {"@" + username}
      </Link>
    );
    lastIndex = offset + match.length;
    return match;
  });

  if (lastIndex < text.length) {
    parts.push(text.slice(lastIndex));
  }

  return parts;
};
