import { defineConfig } from "vitest/config";
import path from "path";

export default defineConfig({
  test: {
    environment: "node",
    globals: true,
    setupFiles: ["./tests/setup.ts"],
    testTimeout: 30000, // integration tests hit real DB
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "."),
    },
  },
});
