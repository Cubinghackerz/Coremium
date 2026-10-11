"use client";
import { AnimatePresence, animate, motion, useInView, useReducedMotion } from "motion/react";
import { useEffect, useRef, useState, type KeyboardEvent, type ReactNode } from "react";
import { cn } from "@/lib/utils";

const ease = [0.22, 1, 0.36, 1] as const;

/* A hairline-ruled grid: the cells share one set of rules instead of each being a separate box. */
function Cell({ className, children }: { className?: string; children: ReactNode }) {
  return <div className={cn("bg-[#070708] p-7 md:p-9", className)}>{children}</div>;
}

function Heading({ children, sub }: { children: ReactNode; sub: string }) {
  return (
    <>
      <h3 className="text-balance text-[26px] font-semibold leading-[1.1] tracking-[-0.03em] text-white md:text-[30px]">{children}</h3>
      <p className="mt-3 max-w-md text-[16px] leading-relaxed text-zinc-400">{sub}</p>
    </>
  );
}

/* The one authored motion on the page: background work moves to the efficiency cores while the app in front stays put. */
const apps = [
  { id: "game", name: "Game", color: "bg-boost", perf: 1, eff: null },
  { id: "browser", name: "Browser", color: "bg-perf", perf: 3, eff: 0 },
  { id: "chat", name: "Chat", color: "bg-mint", perf: 0, eff: 2 },
  { id: "editor", name: "Editor", color: "bg-gpu", perf: 4, eff: 4 },
] as const;
const perfLoad = [0.92, 0.9, 0.7, 0.86, 0.4];
const perfLoadMoved = [0.9, 0.36, 0.34, 0.8, 0.28];
const effLoad = [0.18, 0.2, 0.22, 0.3, 0.2, 0.16];
const effLoadMoved = [0.7, 0.66, 0.6, 0.64, 0.58, 0.5];

function CoreMigration() {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { amount: 0.5 });
  const reduce = useReducedMotion();
  const [moved, setMoved] = useState(false);

  useEffect(() => {
    if (!inView || reduce) return undefined;
    const timer = window.setInterval(() => setMoved((value) => !value), 3600);
    return () => window.clearInterval(timer);
  }, [inView, reduce]);

  const isMoved = reduce ? true : moved;

  const track = (group: "perf" | "eff", index: number, load: number, color: string) => (
    <div key={`${group}-${index}`} className="relative flex h-40 flex-1 flex-col justify-end overflow-hidden rounded-md bg-white/[0.05] md:h-48">
      <motion.div
        className={cn("w-full rounded-md", color)}
        initial={false}
        animate={{ height: `${Math.round(load * 100)}%`, opacity: group === "perf" ? 0.9 : 0.75 }}
        transition={{ duration: 1.4, ease }}
      />
      {apps
        .filter((app) => (isMoved ? app.eff !== null && group === "eff" && app.eff === index : group === "perf" && app.perf === index))
        .map((app) => (
          <motion.span
            key={app.id}
            layoutId={`core-${app.id}`}
            transition={{ duration: 1.1, ease }}
            className={cn("absolute inset-x-1 top-1.5 h-2 rounded-full", app.color)}
          />
        ))}
    </div>
  );

  return (
    <div ref={ref} className="mt-10" role="img" aria-label="Background apps move from the performance cores to the efficiency cores. The app in front stays on performance cores.">
      <div className="flex items-end gap-1.5 md:gap-2">
        <div className="flex flex-1 items-end gap-1.5 md:gap-2">{perfLoad.map((load, i) => track("perf", i, isMoved ? perfLoadMoved[i] : load, "bg-perf/70"))}</div>
        <div className="mx-1 h-48 w-px bg-white/10 md:mx-2" aria-hidden />
        <div className="flex flex-[1.2] items-end gap-1.5 md:gap-2">{effLoad.map((load, i) => track("eff", i, isMoved ? effLoadMoved[i] : load, "bg-eff/70"))}</div>
      </div>
      <div className="mt-4 flex justify-between text-[13px] text-zinc-400">
        <span>Performance cores</span>
        <span>Efficiency cores</span>
      </div>
      <p className="mt-5 text-[15px] leading-relaxed text-zinc-300">
        Illustration. Eligible background work moves to the efficiency cores. The app you&apos;re using stays where it is.
      </p>
    </div>
  );
}

const choices = [
  { name: "Boost", text: "Protected while you use it.", color: "text-boost" },
  { name: "Normal", text: "Left alone.", color: "text-zinc-300" },
  { name: "Yield", text: "Steps aside during a boost.", color: "text-perf" },
  { name: "Eco", text: "Always efficient.", color: "text-eff" },
];

function FourChoices() {
  const [active, setActive] = useState(0);
  const choice = choices[active];

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (event.key !== "ArrowRight" && event.key !== "ArrowLeft") return;
    event.preventDefault();
    const step = event.key === "ArrowRight" ? 1 : -1;
    const next = (active + step + choices.length) % choices.length;
    setActive(next);
    document.getElementById(`choice-${next}`)?.focus();
  }

  return (
    <div className="mt-8">
      <div role="tablist" aria-label="Choices for an app" onKeyDown={onKeyDown} className="flex flex-wrap gap-1.5">
        {choices.map((c, i) => (
          <button
            key={c.name}
            id={`choice-${i}`}
            type="button"
            role="tab"
            aria-selected={i === active}
            aria-controls="choice-panel"
            tabIndex={i === active ? 0 : -1}
            onClick={() => setActive(i)}
            className={cn("relative rounded-full px-4 py-2 text-sm font-medium transition-colors", i === active ? "text-black" : "text-zinc-300 hover:text-white")}
          >
            {i === active ? <motion.span layoutId="choice-pill" className="absolute inset-0 rounded-full bg-white" transition={{ duration: 0.4, ease }} /> : null}
            <span className="relative">{c.name}</span>
          </button>
        ))}
      </div>
      <div id="choice-panel" role="tabpanel" className="mt-6 min-h-[120px]">
        <AnimatePresence mode="wait">
          <motion.div
            key={choice.name}
            initial={{ opacity: 0, y: 10, filter: "blur(6px)" }}
            animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
            exit={{ opacity: 0, y: -6, filter: "blur(4px)" }}
            transition={{ duration: 0.35, ease }}
          >
            <p className={cn("text-[44px] font-semibold leading-none tracking-[-0.04em]", choice.color)}>{choice.name}</p>
            <p className="mt-3 text-[17px] text-zinc-300">{choice.text}</p>
          </motion.div>
        </AnimatePresence>
        <p className="mt-5 text-sm text-zinc-500">Defaults come from what each app is. Your choice always beats the mode.</p>
      </div>
    </div>
  );
}

const decisionLines = [
  { text: "Gaming mode activated.", strong: true },
  { text: "Roblox is protected.", strong: false },
  { text: "Eligible background apps have lower priority.", strong: false },
];

function Decision() {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { once: true, amount: 0.6 });
  const reduce = useReducedMotion();
  return (
    <div ref={ref} className="mt-8 border-t border-white/10 pt-6">
      <p className="mb-4 text-sm text-zinc-500">Example decision, not live activity</p>
      <div className="space-y-1.5 text-[19px] leading-snug tracking-[-0.01em]">
        {decisionLines.map((line, i) => (
          <motion.p
            key={line.text}
            initial={reduce ? false : { opacity: 0, y: 12, filter: "blur(6px)" }}
            animate={inView || reduce ? { opacity: 1, y: 0, filter: "blur(0px)" } : undefined}
            transition={{ duration: 0.6, ease, delay: 0.25 + i * 0.22 }}
            className={line.strong ? "font-semibold text-white" : "text-zinc-400"}
          >
            {line.text}
          </motion.p>
        ))}
      </div>
    </div>
  );
}

function PauseSwitch() {
  const [paused, setPaused] = useState(false);
  return (
    <div className="mt-8">
      <button
        type="button"
        role="switch"
        aria-checked={paused}
        aria-label="Pause Coremium illustration"
        onClick={() => setPaused((v) => !v)}
        className="flex w-full items-center justify-between gap-4 rounded-2xl border border-white/10 p-5 text-left transition-colors hover:border-white/20"
      >
        <span className="text-[16px] text-zinc-300">{paused ? "Normal scheduling restored." : "Coremium lowers background priority."}</span>
        <span className={cn("relative h-7 w-12 shrink-0 rounded-full transition-colors duration-300", paused ? "bg-white/20" : "bg-perf")}>
          <motion.span
            className="absolute top-1 left-1 size-5 rounded-full bg-white shadow-[0_2px_6px_rgba(0,0,0,0.5)]"
            animate={{ x: paused ? 0 : 20 }}
            transition={{ type: "spring", stiffness: 500, damping: 34 }}
          />
        </span>
      </button>
      <p className="mt-4 text-sm text-zinc-500">Illustration. Pause puts every app back to macOS defaults at once.</p>
    </div>
  );
}

/* Illustrative values, styled after the real Advanced panel. They are not a measurement of any particular Mac. */
type Readout = { label: string; value: number | string; format?: (n: number) => string; sub?: string };
const readouts: Readout[] = [
  { label: "P cores", value: 14, format: (n) => `${Math.round(n)}%`, sub: "average load" },
  { label: "E cores", value: 31, format: (n) => `${Math.round(n)}%`, sub: "average load" },
  { label: "Memory", value: "11.0 / 18.0 GB", sub: "61% in use" },
  { label: "Swap used", value: 389, format: (n) => `${Math.round(n)} MB`, sub: "right now" },
  { label: "GPU", value: 22, format: (n) => `${Math.round(n)}%`, sub: "renderer 22% · tiler 22%" },
  { label: "Moved", value: 20, format: (n) => `${Math.round(n)} procs`, sub: "to efficiency cores" },
  { label: "Mem pressure", value: "normal" },
  { label: "Power", value: "AC", sub: "thermal nominal" },
];

function Readout({ item, index }: { item: Readout; index: number }) {
  const ref = useRef<HTMLSpanElement>(null);
  const inView = useInView(ref, { once: true, amount: 0.6 });
  const reduce = useReducedMotion();
  const numeric = typeof item.value === "number";
  const format = item.format ?? ((n: number) => String(Math.round(n)));

  useEffect(() => {
    const el = ref.current;
    if (!el || !numeric || !inView || reduce) return undefined;
    el.textContent = format(0);
    const controls = animate(0, item.value as number, {
      duration: 1.2,
      delay: 0.08 * index,
      ease,
      onUpdate: (v) => {
        el.textContent = format(v);
      },
    });
    return () => controls.stop();
  }, [inView, reduce, numeric, item.value, format, index]);

  return (
    <div className="grid gap-1 border-t border-white/10 py-5">
      <dt className="text-sm text-zinc-400">{item.label}</dt>
      <dd className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
        <span ref={ref} className="text-[28px] font-semibold tracking-[-0.03em] text-white tabular-nums md:text-[32px]">
          {numeric ? format(item.value as number) : item.value}
        </span>
        {item.sub ? <span className="text-sm text-zinc-500">{item.sub}</span> : null}
      </dd>
    </div>
  );
}

function Readouts() {
  return (
    <div>
      <dl className="grid gap-x-10 md:grid-cols-2">
        {readouts.map((item, i) => (
          <Readout key={item.label} item={item} index={i} />
        ))}
      </dl>
      <p className="mt-6 text-sm text-zinc-500">Illustrative values, styled after the real Advanced panel. Your Mac shows its own.</p>
    </div>
  );
}

export function Features() {
  return (
    <section id="how" className="mx-auto max-w-6xl px-6 py-16 md:py-24">
      <h2 className="text-balance mx-auto max-w-3xl text-center text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1.02] tracking-[-0.035em]">
        <span className="text-zinc-400">Busy background apps can compete.</span> <span className="text-white">Give your work more room.</span>
      </h2>
      <div className="mt-16 grid gap-px overflow-hidden rounded-[28px] border border-white/10 bg-white/10 md:grid-cols-6">
        <Cell className="md:col-span-4">
          <Heading sub="On Apple Silicon, background priority favors efficiency cores. On Intel, it lowers scheduling priority. Coremium leaves the app you're using at normal priority; macOS still decides where it runs.">
            Lower background priority. Your work stays protected.
          </Heading>
          <CoreMigration />
        </Cell>
        <Cell className="md:col-span-2">
          <Heading sub="Each app gets one of four. Pick one to see what it means.">Four choices for every app.</Heading>
          <FourChoices />
        </Cell>
        <Cell className="md:col-span-3">
          <Heading sub="Automatic mode says what it changed, in plain words, so it never feels like a black box.">It tells you why.</Heading>
          <Decision />
        </Cell>
        <Cell className="md:col-span-3">
          <Heading sub="Pause puts every app back to macOS defaults at once. Quit Coremium and the same thing happens.">One click puts everything back.</Heading>
          <PauseSwitch />
        </Cell>
        <Cell className="md:col-span-6">
          <div className="grid gap-10 md:grid-cols-[1fr_1.6fr] md:items-start">
            <div>
              <Heading sub="Turn on Advanced when you want the numbers. Nothing is hidden, and nothing leaves your Mac.">Want the numbers? They&apos;re there.</Heading>
            </div>
            <Readouts />
          </div>
        </Cell>
      </div>
    </section>
  );
}
