import type { Metadata, Viewport } from "next";
import { Geist_Mono, Hanken_Grotesk } from "next/font/google";
import "./globals.css";

const hanken = Hanken_Grotesk({ subsets: ["latin"], variable: "--font-hanken", display: "swap" });
const mono = Geist_Mono({ subsets: ["latin"], variable: "--font-geist-mono", display: "swap" });

export const metadata: Metadata = {
  metadataBase: new URL("https://coremium.vercel.app"),
  title: "Coremium: give your app more room to work",
  description:
    "Coremium lives in your Mac's notch and lowers background-app priority while you play, create, code, or run local AI. Your other apps stay open. Free, open source, no account.",
  openGraph: {
    title: "Coremium",
    description: "Give the app you're using more room to work. Free, open source, no account.",
    images: [{ url: "/og.png", width: 1200, height: 630 }],
    type: "website",
  },
  twitter: { card: "summary_large_image", title: "Coremium", description: "Give the app you're using more room to work.", images: ["/og.png"] },
};

export const viewport: Viewport = { themeColor: "#000000", colorScheme: "dark" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${hanken.variable} ${mono.variable}`}>
      <body>{children}</body>
    </html>
  );
}
