import type { Metadata } from "next";
import "./globals.css";
import { PwaRegister } from "@/components/phase4/pwa-register";

export const metadata: Metadata = { title: "NyayaSetu", description: "AICTE student grievance coordination portal" };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body><PwaRegister />{children}</body></html>;
}
