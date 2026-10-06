import type { Metadata, Viewport } from "next";
import { Hanken_Grotesk } from "next/font/google";
import "./globals.css";

const hanken = Hanken_Grotesk({ subsets: ["latin"], variable: "--font-hanken", display: "swap" });

export const metadata: Metadata = {
  metadataBase: new URL("https://coremium.vercel.app"),
  title: "Coremium: give your app more room to work",
  description:
    "Coremium lowers background-app priority while you play, create, code, or run local AI. Your other apps stay open. Free, open source, no account.",
  openGraph: {
    title: "Coremium",
    description: "Give the app you're using more room to work. Free, open source, no account.",
    images: [{ url: "/coremium-panel.png", width: 1552, height: 876 }],
    type: "website",
  },
  twitter: { card: "summary_large_image", title: "Coremium", description: "Give the app you're using more room to work." },
};

export const viewport: Viewport = { themeColor: "#000000", colorScheme: "dark" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={hanken.variable}>
      <body>{children}</body>
    </html>
  );
}
