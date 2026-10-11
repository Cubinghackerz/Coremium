"use client";
import { AiBrain01Icon, BalanceScaleIcon, GameController03Icon, MagicWand01Icon, PaintBoardIcon, SourceCodeIcon } from "@hugeicons/core-free-icons";
import { Icon, type IconSvgElement } from "@/components/icon";
import { AnimatePresence, motion, useInView, useReducedMotion } from "motion/react";
import { useEffect, useMemo, useRef, useState } from "react";
import { cn } from "@/lib/utils";

type ModeId = "automatic" | "gaming" | "creator" | "coding" | "ai" | "balanced";
type Scenario = { mode: string; app: string; others: [string, string, string]; moved: number };

const scenarios: Record<Exclude<ModeId, "automatic" | "balanced">, Scenario> = {
  gaming: { mode: "Gaming", app: "Minecraft", others: ["Chrome", "Discord", "Dropbox"], moved: 18 },
  creator: { mode: "Creator", app: "Final Cut Pro", others: ["Chrome", "Slack", "Spotify"], moved: 21 },
  coding: { mode: "Coding", app: "Xcode", others: ["Chrome", "Slack", "Spotify"], moved: 23 },
  ai: { mode: "Local AI", app: "Ollama", others: ["Chrome", "Final Cut Pro", "Discord"], moved: 14 },
};
const cycle = ["gaming", "coding", "creator", "ai"] as const;

const modes: { id: ModeId; name: string; icon: IconSvgElement }[] = [
  { id: "automatic", name: "Automatic", icon: MagicWand01Icon },
  { id: "gaming", name: "Gaming", icon: GameController03Icon },
  { id: "creator", name: "Creator", icon: PaintBoardIcon },
  { id: "coding", name: "Coding", icon: SourceCodeIcon },
  { id: "ai", name: "Local AI", icon: AiBrain01Icon },
  { id: "balanced", name: "Balanced", icon: BalanceScaleIcon },
];

/* A small seeded generator, so the lanes look the same on the server and in the browser. */
function rng(seed: string) {
  let h = 2166136261;
  for (const c of seed) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
  return () => {
    h = Math.imul(h ^ (h >>> 15), 2246822507);
    h = Math.imul(h ^ (h >>> 13), 3266489909);
    return ((h ^= h >>> 16) >>> 0) / 4294967296;
  };
}

type Kind = "front" | "bg" | "idle";
const mixes: Record<"off" | "on", Record<"p" | "e", [number, number]>> = {
  /* [front share, background share]; the rest is idle time. */
  off: { p: [0.44, 0.42], e: [0, 0.3] },
  on: { p: [0.72, 0.02], e: [0, 0.74] },
};

function strip(seed: string, mix: [number, number]): { kind: Kind; w: number }[] {
  const next = rng(seed);
  const out: { kind: Kind; w: number }[] = [];
  let total = 0;
  while (total < 100) {
    const r = next();
    const kind: Kind = r < mix[0] ? "front" : r < mix[0] + mix[1] ? "bg" : "idle";
    const w = Math.min(100 - total, kind === "idle" ? 2 + next() * 6 : 3 + next() * 9);
    total += w;
    const last = out[out.length - 1];
    if (last && last.kind === kind) last.w += w;
    else out.push({ kind, w });
  }
  return out;
}

const P = 5;
const E = 6;

function Lane({ label, kind, seed, mix, speed }: { label: string; kind: "p" | "e"; seed: string; mix: [number, number]; speed: number }) {
  const segments = useMemo(() => strip(seed, mix), [seed, mix]);
  const half = segments.map((s, i) => (
    <span
      key={i}
      className={cn(
        "h-full shrink-0 border-r-2 border-[#0b0b0e]",
        s.kind === "front" && "bg-boost",
        s.kind === "bg" && "bg-[#7d8496]",
        s.kind === "idle" && "bg-transparent",
      )}
      style={{ width: `${s.w / 2}%` }}
    />
  ));
  return (
    <div className="flex items-center gap-3">
      <span className={cn("w-6 shrink-0 font-mono text-[11px] tabular-nums", kind === "p" ? "text-perf" : "text-eff")}>{label}</span>
      <div className="relative h-[18px] flex-1 overflow-hidden rounded-[5px] bg-white/[0.035] md:h-[22px]">
        <AnimatePresence initial={false}>
          <motion.div
            key={seed}
            className="lane absolute inset-y-0 left-0 flex w-[200%]"
            style={{ ["--lane-speed" as string]: `${speed}s` }}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.7 }}
          >
            {half}
            {half}
          </motion.div>
        </AnimatePresence>
      </div>
    </div>
  );
}

export function Scheduler() {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { amount: 0.25 });
  const reduce = useReducedMotion();
  const [mode, setMode] = useState<ModeId>("automatic");
  const [auto, setAuto] = useState(0);
  const [running, setRunning] = useState(true);

  useEffect(() => {
    if (mode !== "automatic" || !inView || !running || reduce) return undefined;
    const timer = window.setInterval(() => setAuto((i) => (i + 1) % cycle.length), 4200);
    return () => window.clearInterval(timer);
  }, [mode, inView, running, reduce]);

  const balanced = mode === "balanced";
  const key = mode === "automatic" ? cycle[auto] : balanced ? "gaming" : mode;
  const scenario = scenarios[key];
  const moving = running && !balanced;
  const state = moving ? "on" : "off";

  const headline = !running
    ? "Paused. Normal scheduling for every app."
    : balanced
      ? "Nothing moved by the mode"
      : `${scenario.moved} background processes at lower priority`;
  const detail = !running
    ? "Pause puts every app back to macOS defaults at once. Quitting Coremium does the same."
    : balanced
      ? "Balanced mode activated. Only your per-app choices apply."
      : `${mode === "automatic" ? `Automatic chose ${scenario.mode}: ${scenario.app} is in front, so it's protected.` : `${scenario.mode} mode activated. ${scenario.app} is protected.`} ${scenario.others[0]}, ${scenario.others[1]} and ${scenario.others[2]} step aside.`;

  return (
    <section id="how" className="mx-auto max-w-6xl scroll-mt-16 px-5 py-24 md:px-6 md:py-36">
      <div className="grid gap-6 md:grid-cols-[1.25fr_1fr] md:items-end md:gap-16">
        <h2 className="text-balance text-[clamp(34px,5vw,64px)] font-semibold leading-[1] tracking-[-0.04em]">
          Background apps compete for the fast cores. <span className="text-white/45">Coremium moves them aside.</span>
        </h2>
        <p className="text-pretty text-[16px] leading-relaxed text-zinc-400 md:pb-2">
          On Apple Silicon, lower priority tells macOS to prefer the efficiency cores for that work. On Intel, it lowers scheduling priority. The app you&apos;re
          using stays at normal priority, and macOS still decides where everything runs.
        </p>
      </div>

      <div ref={ref} data-paused={!inView || reduce ? "true" : "false"} className="mt-14 overflow-hidden rounded-[28px] bg-ink ring-1 ring-inset ring-white/10">
        <div className="flex flex-col gap-4 border-b border-white/[0.07] p-4 md:flex-row md:items-center md:justify-between md:p-5">
          <div role="radiogroup" aria-label="Mode" className="flex flex-wrap gap-1">
            {modes.map((m) => {
              const selected = m.id === mode;
              return (
                <button
                  key={m.id}
                  type="button"
                  role="radio"
                  aria-checked={selected}
                  onClick={() => setMode(m.id)}
                  className={cn(
                    "relative inline-flex h-9 items-center gap-2 rounded-full px-3.5 text-[13.5px] font-medium transition-colors",
                    selected ? "text-black" : "text-zinc-300 hover:bg-white/[0.06] hover:text-white",
                  )}
                >
                  {selected ? <motion.span layoutId="mode-pill" className="absolute inset-0 rounded-full bg-white" transition={{ type: "spring", stiffness: 500, damping: 40 }} /> : null}
                  <Icon icon={m.icon} className="relative size-4" />
                  <span className="relative">{m.name}</span>
                </button>
              );
            })}
          </div>
          <button
            type="button"
            role="switch"
            aria-checked={running}
            onClick={() => setRunning((v) => !v)}
            className="inline-flex items-center gap-3 self-start rounded-full py-1 pl-3 pr-1 text-[13.5px] text-zinc-300 hover:text-white md:self-auto"
          >
            {running ? "Coremium on" : "Paused"}
            <span className={cn("relative h-7 w-12 rounded-full transition-colors duration-300", running ? "bg-boost" : "bg-white/15")}>
              <motion.span
                className="absolute left-1 top-1 size-5 rounded-full bg-white shadow-[0_2px_6px_rgba(0,0,0,0.45)]"
                animate={{ x: running ? 20 : 0 }}
                transition={{ type: "spring", stiffness: 500, damping: 34 }}
              />
            </span>
          </button>
        </div>

        <div className="grid gap-8 p-5 md:grid-cols-[1fr_280px] md:gap-10 md:p-8">
          <div role="img" aria-label={`Illustration of ${P} performance and ${E} efficiency cores. ${headline}. ${detail}`}>
            <div className="mb-3 flex justify-between text-[12px] text-zinc-500">
              <span>Performance cores</span>
              <span>last 10 seconds</span>
            </div>
            <div className="space-y-1.5">
              {Array.from({ length: P }, (_, i) => (
                <Lane key={`p${i}`} label={`P${i + 1}`} kind="p" seed={`p${i}-${key}-${state}`} mix={mixes[state].p} speed={16 + ((i * 7) % 6)} />
              ))}
            </div>
            <div className="mb-3 mt-6 text-[12px] text-zinc-500">Efficiency cores</div>
            <div className="space-y-1.5">
              {Array.from({ length: E }, (_, i) => (
                <Lane key={`e${i}`} label={`E${i + 1}`} kind="e" seed={`e${i}-${key}-${state}`} mix={mixes[state].e} speed={18 + ((i * 5) % 7)} />
              ))}
            </div>
          </div>

          <div className="flex flex-col justify-between gap-8 md:border-l md:border-white/[0.07] md:pl-10">
            <div aria-live="polite">
              <AnimatePresence mode="wait">
                <motion.div
                  key={headline + detail}
                  initial={{ opacity: 0, y: 8, filter: "blur(6px)" }}
                  animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                  exit={{ opacity: 0, y: -4, filter: "blur(4px)" }}
                  transition={{ duration: 0.35 }}
                >
                  <p className="flex gap-2.5 text-[17px] font-semibold leading-snug text-white">
                    <span className={cn("mt-2 size-2 shrink-0 rounded-full", moving ? "bg-boost" : "bg-zinc-500")} />
                    {headline}
                  </p>
                  <p className="mt-3 pl-[18px] text-[15px] leading-relaxed text-zinc-400">{detail}</p>
                </motion.div>
              </AnimatePresence>
            </div>
            <ul className="space-y-2.5 text-[13px] text-zinc-400">
              <li className="flex items-center gap-2.5">
                <span className="h-3 w-5 rounded-[3px] bg-boost" /> {scenario.app}, the app in front
              </li>
              <li className="flex items-center gap-2.5">
                <span className="h-3 w-5 rounded-[3px] bg-[#7d8496]" /> Background apps
              </li>
              <li className="flex items-center gap-2.5">
                <span className="h-3 w-5 rounded-[3px] bg-white/[0.06] ring-1 ring-inset ring-white/10" /> Free time on that core
              </li>
              <li className="pt-2 text-zinc-500">Illustration of the idea, not a measurement. On a quiet Mac there may be nothing to move.</li>
            </ul>
          </div>
        </div>
      </div>
    </section>
  );
}
