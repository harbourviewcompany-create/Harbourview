import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  experimental: {
    // Required for server actions
    serverActions: {
      allowedOrigins: [process.env.APP_URL ?? "http://localhost:3000"],
    },
  },
};

export default nextConfig;
