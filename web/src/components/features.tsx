"use client";
import { PauseCircle, SlidersHorizontal } from "lucide-react";
import { useState } from "react";
import { cn } from "@/lib/utils";

function Tile({ className, children }: { className?: string; children: React.ReactNode }) {
  return (
    <div
      className={cn(
        "group relative overflow-hidden rounded-[28px] bg-white/[0.035] p-7 ring-1 ring-inset ring-white/10 md:p-9",
        className,
      )}
    >
      {children}
    </div>
  );
}

const Title = ({ children, sub }: { children: React.ReactNode; sub: string }) => (
  <>
    <h3 className="text-balance text-[26px] font-semibold leading-[1.1] tracking-[-0.03em] text-white md:text-[30px]">{children}</h3>
    <p className="mt-3 max-w-md text-[16px] leading-relaxed text-zinc-400">{sub}</p>
  </>
);

/* two kinds of cores: the idea in one strip */
function CoreStrip() {
  const on = true;
  const perf = Array.from({ length: 5 });
  const eff = Array.from({ length: 6 });
  return (
    <div className="mt-8" aria-hidden>
      <div className="grid grid-cols-[repeat(5,1.5fr)_repeat(6,1fr)] items-end gap-1.5 md:gap-2">
        {perf.map((_, i) => (
          <div key={i} className="relative h-16 overflow-hidden rounded-lg bg-white/[0.05] md:h-20">
            <div className="absolute inset-0 bg-perf transition-opacity duration-[1400ms]" style={{ opacity: on && i > 1 ? 0.08 : 0.92 }} />
          </div>
        ))}
        {eff.map((_, i) => (
          <div key={i} className="relative h-11 overflow-hidden rounded-lg bg-white/[0.05] md:h-14">
            <div className="absolute inset-0 bg-eff transition-opacity duration-[1400ms]" style={{ opacity: on ? (i % 2 ? 0.55 : 0.32) : 0.08 }} />
          </div>
        ))}
      </div>
      <div className="mt-3 flex justify-between text-[13px] text-zinc-400">
        <span>Performance cores</span>
        <span>Efficiency cores</span>
      </div>
      <p className="mt-4 text-[15px] text-zinc-300">{on ? "Illustration: eligible background work has lower priority." : "Illustration: busy apps can compete for CPU time."}</p>
    </div>
  );
}

const choices = [
  { name: "Boost", text: "Protected while you use it.", color: "text-boost" },
  { name: "Normal", text: "Left alone.", color: "text-zinc-400" },
  { name: "Yield", text: "Steps aside during a boost.", color: "text-perf" },
  { name: "Eco", text: "Always efficient.", color: "text-eff" },
];

function Decisions() {
  return (
    <div className="relative mt-8 min-h-[148px] rounded-2xl bg-black/60 p-5 ring-1 ring-inset ring-white/10">
      <p className="mb-3 text-sm text-zinc-400">Example decision, not live activity</p>
      <p className="text-[19px] leading-snug tracking-[-0.01em]">
        <span className="font-semibold text-white">Gaming mode activated.</span>{" "}
        <span className="text-zinc-400">Roblox is protected. Eligible background apps have lower priority.</span>
      </p>
    </div>
  );
}

function PauseSwitch() {
  const [paused, setPaused] = useState(false);
  return (
    <button
      type="button"
      onClick={() => setPaused((v) => !v)}
      aria-pressed={paused}
      className="mt-8 flex w-full items-center justify-between gap-4 rounded-2xl bg-black/60 p-5 text-left ring-1 ring-inset ring-white/10 transition-colors hover:bg-black/40"
    >
      <span className="text-[16px] text-zinc-300">{paused ? "Illustration: normal scheduling restored." : "Illustration: Coremium lowers background priority."}</span>
      <span className={cn("relative h-7 w-12 shrink-0 rounded-full transition-colors duration-300", paused ? "bg-yellow-300" : "bg-white/15")}>
        <span className={cn("absolute top-1 size-5 rounded-full bg-white shadow transition-all duration-300", paused ? "left-6 bg-black" : "left-1")} />
      </span>
    </button>
  );
}

export function Features() {
  return (
    <section id="how" className="mx-auto max-w-6xl px-6 py-16 md:py-24">
      <h2 className="text-balance mx-auto max-w-3xl text-center text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1.02] tracking-[-0.035em]">
        <span className="text-zinc-400">Busy background apps can compete.</span> <span className="text-white">Give your work more room.</span>
      </h2>
      <div className="mt-16 grid gap-4 md:grid-cols-6">
        <Tile className="md:col-span-4">
          <Title sub="On Apple Silicon, background priority favors efficiency cores. On Intel, it lowers scheduling priority. Coremium leaves the app you're using at normal priority; macOS still decides where it runs.">
            Lower background priority. Your work stays protected.
          </Title>
          <CoreStrip />
        </Tile>
        <Tile className="md:col-span-2">
          <Title sub="Defaults come from what each app is. Your choice always beats the mode.">Four choices for every app.</Title>
          <ul className="mt-6 space-y-3">
            {choices.map((c) => (
              <li key={c.name} className="flex items-baseline justify-between gap-4 border-t border-line pt-3 first:border-0 first:pt-0">
                <span className={cn("text-[22px] font-semibold tracking-[-0.02em]", c.color)}>{c.name}</span>
                <span className="text-right text-[14.5px] text-zinc-400">{c.text}</span>
              </li>
            ))}
          </ul>
        </Tile>
        <Tile className="md:col-span-3">
          <Title sub="Automatic mode says what it changed, in plain words, so it never feels like a black box.">It tells you why.</Title>
          <Decisions />
        </Tile>
        <Tile className="md:col-span-3">
          <Title sub="Pause puts every app back to macOS defaults at once. Quit Coremium and the same thing happens.">
            One click puts everything back.
          </Title>
          <PauseSwitch />
          <p className="mt-4 flex items-center gap-2 text-sm text-zinc-400">
            <PauseCircle className="size-4" aria-hidden /> Try the switch.
          </p>
        </Tile>
        <Tile className="md:col-span-6">
          <div className="grid gap-8 md:grid-cols-[1fr_1.1fr] md:items-center">
            <div>
              <Title sub="Turn on Advanced when you want the numbers. Nothing is hidden, and nothing leaves your Mac.">Want the numbers? They&apos;re there.</Title>
            </div>
            <ul className="grid grid-cols-2 gap-x-6 gap-y-3 text-[15px] text-zinc-300">
              {["Per-core load, performance and efficiency", "Memory, swap and pressure", "Process counts and PIDs", "Why each rule applies to each app", "Time a boost ran, and how many processes moved", "Coremium's own CPU cost", "A Storage tab: what fills your disk, cleared to the Trash only", "A System tab: memory hogs, swap and the helpers that start with your Mac"].map((t) => (
                <li key={t} className="flex gap-3">
                  <SlidersHorizontal className="mt-1 size-4 shrink-0 text-perf" aria-hidden />
                  {t}
                </li>
              ))}
            </ul>
          </div>
        </Tile>
      </div>
    </section>
  );
}
