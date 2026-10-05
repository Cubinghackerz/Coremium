"use client";
import { motion, useReducedMotion, useScroll, useTransform } from "motion/react";
import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { CopyLine } from "@/components/install";
import { INSTALL_CMD, INSTALL_CMD_WINDOWS, REPO } from "@/lib/utils";

export function Hero() {
  const ref = useRef<HTMLDivElement>(null);
  const reduce = useReducedMotion();
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start 0.9", "start 0.15"] });
  const rotate = useTransform(scrollYProgress, [0, 1], [reduce ? 0 : 22, 0]);
  const scale = useTransform(scrollYProgress, [0, 1], [reduce ? 1 : 0.9, 1]);
  const lift = useTransform(scrollYProgress, [0, 1], [reduce ? 0 : 60, 0]);

  return (
    <section id="top" className="relative overflow-hidden pt-36 md:pt-44">
      {/* horizon glow: the edge of a chip lit from below */}
      <div aria-hidden className="pointer-events-none absolute inset-x-0 bottom-0 h-[70%]">
        <div className="absolute left-1/2 top-[34%] aspect-square w-[190%] -translate-x-1/2 rounded-full border-t border-perf/50 bg-[radial-gradient(ellipse_at_50%_0%,rgba(98,228,255,0.16),transparent_55%)] shadow-[0_-40px_140px_20px_rgba(98,228,255,0.18)]" />
        <div className="absolute left-1/2 top-[34%] aspect-square w-[130%] -translate-x-1/2 rounded-full bg-[radial-gradient(ellipse_at_50%_0%,rgba(123,135,255,0.18),transparent_50%)] blur-2xl" />
      </div>

      <div className="relative mx-auto max-w-6xl px-6 text-center">
        <h1
          className="rise text-balance mx-auto max-w-4xl text-[clamp(44px,7.4vw,92px)] font-semibold leading-[0.98] tracking-[-0.04em]"
        >
          <span className="text-zinc-500">Keep what matters smooth,</span>
          <br />
          <span className="bg-gradient-to-b from-white to-zinc-300 bg-clip-text text-transparent">without closing anything.</span>
        </h1>
        <p
          style={{ animationDelay: "120ms" }}
          className="rise mx-auto mt-7 max-w-xl text-lg leading-relaxed text-zinc-400"
        >
          Coremium lives in your Mac&apos;s notch. While you play, render, code or run a local model, it moves everything else to the efficiency cores.
        </p>
        <div
          style={{ animationDelay: "220ms" }}
          className="rise mt-10 flex flex-wrap items-center justify-center gap-3"
        >
          <HeroInstall />
        </div>
        <p className="mt-5 text-sm text-zinc-500">
          Free and open source. No account, no network access. Prefer a disk image or zip?{" "}
          <a className="text-zinc-300 underline decoration-zinc-600 underline-offset-4 hover:decoration-white" href={`${REPO}/releases`}>GitHub Releases</a>
          {" · "}
          <a className="text-zinc-300 underline decoration-zinc-600 underline-offset-4 hover:decoration-white" href="#install">Why the terminal?</a>
        </p>
      </div>

      <div ref={ref} className="relative mx-auto mt-20 max-w-5xl px-4 pb-24 md:mt-28 [perspective:1600px]">
        <motion.div style={{ rotateX: rotate, scale, y: lift, transformOrigin: "50% 100%" }} className="relative">
          <div className="absolute -inset-px rounded-[34px] bg-gradient-to-b from-white/25 to-white/0" aria-hidden />
          <Image
            src="/coremium-panel.png"
            alt="The Coremium panel open from the notch: modes, status, per-app Boost, Normal, Yield and Eco choices, and today's summary."
            width={1552}
            height={876}
            priority
            className="relative w-full rounded-[34px] bg-black shadow-[0_60px_120px_-30px_rgba(98,228,255,0.25)]"
          />
        </motion.div>
        <p className="mt-6 text-center text-sm text-zinc-500">Coremium on a 14-inch MacBook Pro running macOS 27.</p>
      </div>
    </section>
  );
}

/** The recommended install: one terminal command, picked for the visitor's OS (switchable). */
function HeroInstall() {
  const [os, setOs] = useState<"mac" | "windows">("mac");
  useEffect(() => { if (/Windows/i.test(navigator.userAgent)) setOs("windows"); }, []);
  return (
    <div className="w-full max-w-2xl text-left">
      <div className="mb-3 flex items-center justify-between gap-4 text-sm">
        <span className="text-zinc-400">{os === "mac" ? "Paste into Terminal:" : "Paste into PowerShell (beta):"}</span>
        <div className="flex rounded-full bg-white/[0.06] p-0.5 ring-1 ring-inset ring-white/10" role="group" aria-label="Operating system">
          {(["mac", "windows"] as const).map((o) => (
            <button key={o} type="button" aria-pressed={os === o} onClick={() => setOs(o)}
              className={`rounded-full px-3 py-1 text-[13px] font-medium transition-colors ${os === o ? "bg-white text-black" : "text-zinc-400 hover:text-white"}`}>
              {o === "mac" ? "macOS" : "Windows"}
            </button>
          ))}
        </div>
      </div>
      <CopyLine text={os === "mac" ? INSTALL_CMD : INSTALL_CMD_WINDOWS} label={os === "mac" ? "macOS install command" : "Windows install command"} />
    </div>
  );
}
