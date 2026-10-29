import babel from "@rolldown/plugin-babel";
import tailwindcss from "@tailwindcss/vite";
import { tanstackRouter } from "@tanstack/router-plugin/vite";
import react, { reactCompilerPreset } from "@vitejs/plugin-react";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

// The API runs on Phoenix (awrad-server-next). In development, Vite proxies /api and
// /socket to it, so the browser sees one origin, exactly as the production reverse
// proxy does (ADR 0001). Cookies and CSRF work the same in both.
const api = process.env.AWRAD_API_ORIGIN ?? "http://localhost:4000";

export default defineConfig({
  plugins: [
    // Must run before react(): generates src/routeTree.gen.ts from src/routes/.
    tanstackRouter({ target: "react", autoCodeSplitting: true }),
    react(),
    babel({ presets: [reactCompilerPreset()] }),
    tailwindcss(),
  ],
  resolve: {
    alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) },
  },
  server: {
    port: 5180, // fixed and uncommon, so it never clashes with other local projects (the R2 CORS rule allows it)
    strictPort: true,
    proxy: {
      "/api": { target: api, changeOrigin: false },
      "/socket": { target: api, ws: true, changeOrigin: false },
    },
  },
  test: {
    environment: "jsdom",
    // A reserved, unresolvable origin: a request no mock handles can never reach a real
    // service (MSW's onUnhandledFrame "error" reports, but doesn't stop, the request).
    environmentOptions: { jsdom: { url: "http://web.awrad.test" } },
    globals: true,
    setupFiles: ["./src/test/setup.ts"],
    css: false,
  },
});
