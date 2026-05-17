// @ts-check
import { defineConfig } from "astro/config";

import tailwindcss from "@tailwindcss/vite";

// https://astro.build/config
export default defineConfig({
  site: "https://wesleynw.github.io",
  base: "/splajompy",
  vite: {
    plugins: [tailwindcss()],
  },
});
