import type { Metadata, Viewport } from "next";
import { Hanken_Grotesk } from "next/font/google";
import "./globals.css";

const hanken = Hanken_Grotesk({ subsets: ["latin"], variable: "--font-hanken", display: "swap" });

export const metadata: Metadata = {
  metadataBase: new URL("https://coremium.vercel.app"),
  title: "Coremium: keep what matters smooth",
  description:
    "Coremium lives in your Mac's notch and moves background apps to the efficiency cores while the app you're using stays smooth. Nothing is closed. Free and open source.",
  openGraph: {
    title: "Coremium",
    description: "Keep what matters smooth, without closing anything.",
    images: [{ url: "/coremium-panel.png", width: 1552, height: 876 }],
    type: "website",
  },
  twitter: { card: "summary_large_image", title: "Coremium", description: "Keep what matters smooth, without closing anything." },
};

export const viewport: Viewport = { themeColor: "#000000", colorScheme: "dark" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={hanken.variable}>
      <body>{children}</body>
    </html>
  );
}
