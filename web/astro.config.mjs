// @ts-check
import { defineConfig } from "astro/config";
import { defineConfig, fontProviders } from "astro/config";

import tailwindcss from "@tailwindcss/vite";

// https://astro.build/config
export default defineConfig({
  fonts: [{
    provider: fontProviders.local(),
    name: "Splajompy",
    cssVariable: "--font-splajompy",
    options: {
      variants: [{
        src: ['./src/assets/Splajompy.ttf'],
        weight: 'normal',
        style: 'normal'
      }]
    }
  }],
  site: "https://splajompy.com",
  vite: {
    plugins: [tailwindcss()],
  },
});
