import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Harbourview",
  description: "Evidence-first intelligence platform",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
