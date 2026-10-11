"use client";
import { CpuIcon, LockIcon, Timer02Icon } from "@hugeicons/core-free-icons";
import { Icon } from "@/components/icon";
import { useInView, useReducedMotion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";

/* Simulated readings in the layout of the real Advanced panel (an M3 Pro: 5 performance and 6 efficiency cores).
   They drift like real ones every 2 seconds while on screen. They are not read from the visitor's Mac. */
const P = 5;
const E = 6;
const COLS = 48;

function seeded(seed: number) {
  let s = seed;
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
}

type Reading = {
  cores: number[];
  memory: number;
  swap: number;
  gpu: number;
  tiler: number;
  moved: number;
};

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));
const centre = (i: number) => (i < P ? 0.11 : 0.3);

function step(prev: Reading, r: () => number): Reading {
  return {
    cores: prev.cores.map((v, i) => {
      const spike = r() < 0.06 ? 0.25 + r() * 0.3 : 0;
      const next = v + (centre(i) - v) * 0.35 + (r() - 0.5) * 0.12 + spike;
      return clamp(next, 0.02, 0.96);
    }),
    memory: clamp(prev.memory + (r() - 0.5) * 0.12, 10.6, 11.6),
    swap: Math.round(clamp(prev.swap + (r() - 0.45) * 6, 372, 424)),
    gpu: clamp(prev.gpu + (0.22 - prev.gpu) * 0.3 + (r() - 0.5) * 0.08, 0.06, 0.6),
    tiler: 0,
    moved: Math.round(clamp(prev.moved + (r() < 0.25 ? (r() < 0.5 ? -1 : 1) : 0), 17, 23)),
  };
}

function initial(): { now: Reading; history: number[][] } {
  const r = seeded(7);
  let now: Reading = { cores: [0.09, 0.09, 0.07, 0.14, 0.12, 0.5, 0.41, 0.33, 0.28, 0.18, 0.14], memory: 11.0, swap: 389, gpu: 0.22, tiler: 0.22, moved: 20 };
  const history: number[][] = [];
  for (let c = 0; c < COLS; c++) {
    now = step(now, r);
    history.push(now.cores);
  }
  now = { cores: [0.09, 0.09, 0.07, 0.14, 0.12, 0.5, 0.41, 0.33, 0.28, 0.18, 0.14], memory: 11.0, swap: 389, gpu: 0.22, tiler: 0.22, moved: 20 };
  history[COLS - 1] = now.cores;
  return { now, history };
}

const pct = (v: number) => `${Math.round(v * 100)}%`;
const avg = (a: number[]) => a.reduce((s, v) => s + v, 0) / a.length;

function HeatStrip({ history }: { history: number[][] }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const dpr = window.devicePixelRatio || 1;
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.scale(dpr, dpr);
    ctx.clearRect(0, 0, w, h);
    const rows = P + E;
    const gap = 2;
    const rh = (h - gap * rows - 6) / rows;
    const cw = w / COLS;
    history.forEach((col, x) => {
      col.forEach((load, y) => {
        const top = y * (rh + gap) + (y >= P ? 6 : 0);
        ctx.fillStyle = y < P ? `rgba(98,228,255,${0.06 + load * 0.94})` : `rgba(123,135,255,${0.06 + load * 0.94})`;
        ctx.fillRect(x * cw, top, Math.max(1, cw - 1.5), rh);
      });
    });
  }, [history]);
  return <canvas ref={ref} className="h-[132px] w-full" aria-hidden />;
}

function Chip() {
  const pins = Array.from({ length: 7 });
  return (
    <div className="relative mx-auto grid size-[132px] place-items-center" aria-hidden>
      <div className="absolute inset-x-6 top-0 flex justify-between">{pins.map((_, i) => <span key={i} className="h-3 w-1.5 rounded-[2px] bg-zinc-600" />)}</div>
      <div className="absolute inset-x-6 bottom-0 flex justify-between">{pins.map((_, i) => <span key={i} className="h-3 w-1.5 rounded-[2px] bg-zinc-600" />)}</div>
      <div className="absolute inset-y-6 left-0 flex flex-col justify-between">{pins.slice(0, 5).map((_, i) => <span key={i} className="h-1.5 w-3 rounded-[2px] bg-zinc-600" />)}</div>
      <div className="absolute inset-y-6 right-0 flex flex-col justify-between">{pins.slice(0, 5).map((_, i) => <span key={i} className="h-1.5 w-3 rounded-[2px] bg-zinc-600" />)}</div>
      <div className="grid size-[96px] place-items-center rounded-[22px] bg-gradient-to-b from-zinc-700 to-zinc-900 p-[3px] shadow-[0_10px_30px_-10px_rgba(0,0,0,0.8)]">
        <div className="grid size-full place-items-center rounded-[19px] bg-[#16161a] ring-1 ring-inset ring-white/10">
          <span className="text-[15px] font-semibold tracking-[0.02em] text-zinc-100">M3 Pro</span>
        </div>
      </div>
    </div>
  );
}

function Cell({ v }: { v: number }) {
  return (
    <span
      className={cn("grid h-8 flex-1 place-items-center rounded-[6px] font-mono text-[12.5px] tabular-nums transition-colors duration-700", v > 0.45 ? "text-black" : "text-zinc-100")}
      style={{ backgroundColor: `rgba(255,255,255,${0.08 + v * 0.62})` }}
    >
      {Math.round(v * 100)}
    </span>
  );
}

export function Telemetry() {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { amount: 0.3 });
  const reduce = useReducedMotion();
  const [state, setState] = useState(initial);
  const random = useRef(seeded(42));

  useEffect(() => {
    if (!inView || reduce) return undefined;
    const timer = window.setInterval(() => {
      if (document.hidden) return;
      setState(({ now, history }) => {
        const next = step(now, random.current);
        next.tiler = next.gpu;
        return { now: next, history: [...history.slice(1), next.cores] };
      });
    }, 2000);
    return () => window.clearInterval(timer);
  }, [inView, reduce]);

  const { now, history } = state;
  const p = now.cores.slice(0, P);
  const e = now.cores.slice(P);
  const rows: [string, string][] = [
    ["P cores", `${pct(avg(p))} avg`],
    ["E cores", `${pct(avg(e))} avg`],
    ["All cores", pct(avg(now.cores))],
    ["Memory", `${now.memory.toFixed(1)} / 18.0 GB (${Math.round((now.memory / 18) * 100)}%)`],
    ["Mem pressure", "normal"],
    ["Swap used", `${now.swap} MB`],
    ["Cores", "5P+6E · 14 GPU"],
    ["L2", "16 MB P · 4 MB E"],
    ["GPU", `${pct(now.gpu)} · renderer ${pct(now.gpu)} · tiler ${pct(now.tiler || now.gpu)}`],
    ["Thermal", "nominal"],
    ["Power", "AC"],
    ["Moved", `${now.moved} procs`],
  ];

  return (
    <section id="numbers" aria-labelledby="numbers-heading" className="scroll-mt-16 border-y border-white/[0.06] bg-[radial-gradient(70%_60%_at_80%_40%,rgba(98,228,255,0.07),transparent_70%)]">
      <div className="mx-auto grid max-w-6xl gap-14 px-5 py-24 md:px-6 md:py-36 lg:grid-cols-[1fr_1.35fr] lg:items-center lg:gap-16">
        <div>
          <h2 id="numbers-heading" className="text-balance text-[clamp(34px,5vw,64px)] font-semibold leading-[1] tracking-[-0.04em]">
            Want the numbers? <span className="text-white/45">Turn on Advanced.</span>
          </h2>
          <p className="text-pretty mt-6 max-w-md text-[16px] leading-relaxed text-zinc-400">
            Every decision comes with the readings behind it: per-core load, memory pressure, swap, GPU and how many processes were moved.
          </p>
          <ul className="mt-10 space-y-5 text-[15px] text-zinc-300">
            <li className="flex gap-3.5">
              <Icon icon={Timer02Icon} className="mt-0.5 size-5 shrink-0 text-perf" />
              Refreshed every 2 seconds while the panel is open, and far less often when it&apos;s closed.
            </li>
            <li className="flex gap-3.5">
              <Icon icon={LockIcon} className="mt-0.5 size-5 shrink-0 text-perf" />
              Nothing leaves your Mac. No account, no telemetry.
            </li>
            <li className="flex gap-3.5">
              <Icon icon={CpuIcon} className="mt-0.5 size-5 shrink-0 text-perf" />
              Coremium shows its own CPU use too, so you can judge the cost.
            </li>
          </ul>
        </div>

        <div ref={ref}>
          <div className="grid gap-8 rounded-[32px] bg-black p-6 ring-1 ring-inset ring-white/12 shadow-[0_40px_100px_-40px_rgba(98,228,255,0.25)] md:grid-cols-[0.8fr_1.2fr] md:p-8">
            <div>
              <Chip />
              <p className="mt-6 text-[11px] font-semibold tracking-[0.14em] text-zinc-500">CORE LOAD %</p>
              <div className="mt-2 space-y-1.5">
                <div className="flex items-center gap-1.5">
                  <span className="w-3 font-mono text-[11px] text-perf">P</span>
                  {p.map((v, i) => <Cell key={i} v={v} />)}
                </div>
                <div className="flex items-center gap-1.5">
                  <span className="w-3 font-mono text-[11px] text-eff">E</span>
                  {e.map((v, i) => <Cell key={i} v={v} />)}
                </div>
              </div>
              <div className="mt-6">
                <div className="mb-2 flex justify-between text-[11px] text-zinc-500">
                  <span>96 s ago</span>
                  <span>now</span>
                </div>
                <HeatStrip history={history} />
              </div>
            </div>
            <dl className="font-mono text-[12.5px]">
              {rows.map(([k, v]) => (
                <div key={k} className="flex items-baseline justify-between gap-4 border-b border-white/[0.06] py-[7px] last:border-0">
                  <dt className="text-zinc-500">{k}</dt>
                  <dd className="text-right tabular-nums text-zinc-100">{v}</dd>
                </div>
              ))}
            </dl>
          </div>
          <p className="mt-4 text-center text-[13px] text-zinc-500">Simulated readings in the layout of the real Advanced panel. Your Mac shows its own.</p>
        </div>
      </div>
    </section>
  );
}
