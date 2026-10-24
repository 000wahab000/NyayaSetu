import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = { title: "NyayaSetu", description: "AICTE student grievance coordination portal" };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
