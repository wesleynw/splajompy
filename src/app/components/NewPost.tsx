"use client";

import { useRef } from "react";
import { insertPost } from "../lib/actions";

export default function Page() {
  const ref = useRef<HTMLFormElement>(null);

  return (
    <form
      action={async (formData) => {
        await insertPost(formData);
        ref.current?.reset();
      }}
      ref={ref}
    >
      <input type="text" name="text" />
      <button type="submit">post</button>
    </form>
  );
}
