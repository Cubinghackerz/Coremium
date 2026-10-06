"use client";

import { useState } from "react";

const scenarios = [
  { label: "Play", app: "Your game", others: ["Browser", "Chat"] },
  { label: "Create", app: "Your video editor", others: ["Browser", "Chat"] },
  { label: "Code", app: "Your editor or build", others: ["Game", "Video editor"] },
  { label: "Local AI", app: "Your local model", others: ["Browser", "Video editor"] },
] as const;

export function Demo() {
  const [scenario, setScenario] = useState(0);
  const [enabled, setEnabled] = useState(true);
  const current = scenarios[scenario];

  return (
    <div id="demo" className="mx-auto my-12 max-w-4xl scroll-mt-24 px-6 md:my-16">
      <div className="overflow-hidden rounded-2xl border border-line bg-white/[0.035]">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-line px-5 py-4">
          <p className="text-sm text-zinc-400">Interactive illustration · No performance measurements</p>
          <div className="flex flex-wrap gap-1" role="group" aria-label="Example workload">
            {scenarios.map(({ label }, i) => (
              <button key={label} type="button" aria-pressed={scenario === i} onClick={() => setScenario(i)}
                className={`min-h-11 rounded-lg px-3 text-sm transition-colors ${scenario === i ? "bg-white text-black" : "text-zinc-300 hover:bg-white/10"}`}>
                {label}
              </button>
            ))}
          </div>
        </div>
        <div className="grid gap-5 p-5 sm:grid-cols-2 sm:p-7">
          <div className="rounded-xl border border-perf/20 p-5">
            <h2 className="text-sm font-medium text-perf">The app you&apos;re using</h2>
            <p className="mt-4 text-xl font-semibold text-white">{current.app}</p>
            <p className="mt-2 text-sm text-zinc-400">{enabled ? "Protected at normal priority" : "Normal priority"}</p>
          </div>
          <div className="rounded-xl border border-line p-5">
            <h2 className="text-sm font-medium text-zinc-300">Eligible background apps</h2>
            <ul className="mt-4 space-y-3">
              {current.others.map((app) => (
                <li key={app} className="flex flex-wrap items-center justify-between gap-2 text-sm">
                  <span className="text-zinc-200">{app}</span>
                  <span className={enabled ? "text-mint" : "text-zinc-400"}>{enabled ? "Lower priority" : "Normal priority"}</span>
                </li>
              ))}
            </ul>
            <p className="mt-4 text-sm text-zinc-400">All apps stay open.</p>
          </div>
        </div>
        <div className="flex flex-col items-start justify-between gap-4 border-t border-line px-5 py-5 sm:flex-row sm:items-center sm:px-7">
          <p className="max-w-lg text-sm leading-relaxed text-zinc-300" role="status">
            {enabled ? `Example decision: protect ${current.app.toLowerCase()}; lower eligible background apps' priority.`
              : "Example decision: paused. Normal scheduling restored for all apps."}
          </p>
          <button type="button" aria-pressed={enabled} onClick={() => setEnabled((value) => !value)}
            className="min-h-11 shrink-0 rounded-full bg-white px-5 text-sm font-medium text-black hover:bg-zinc-200">
            {enabled ? "Pause illustration" : "Resume illustration"}
          </button>
        </div>
      </div>
      <p className="mt-4 text-center text-sm leading-relaxed text-zinc-400">
        Most useful when background CPU work competes with your app. On a quiet Mac, there may be nothing to change.
      </p>
    </div>
  );
}
