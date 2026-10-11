"use client";

import Image from "next/image";
import { useState } from "react";
import { cn } from "@/lib/utils";

/* Real screenshots of the notch panel, taken on one Mac (M3 Pro). Unedited. Numbers differ on every Mac. */
const screens = [
  {
    id: "apps",
    label: "Apps",
    src: "/screens/notch-apps.png",
    title: "One choice per app",
    body: "Every running app gets Boost, Normal, Yield or Eco. The line under the modes says what Coremium changed and why.",
  },
  {
    id: "advanced",
    label: "Advanced",
    src: "/screens/notch-apps-advanced.png",
    title: "The numbers behind it",
    body: "Advanced mode shows per-core load, memory pressure, swap and GPU use next to each decision. Turn it off to keep it simple.",
  },
  {
    id: "system",
    label: "System",
    src: "/screens/notch-system.png",
    title: "Memory, in plain words",
    body: "Pressure, swap and the apps using the most memory. Hide or quit one from here; Coremium never quits anything on its own.",
  },
  {
    id: "storage",
    label: "Storage",
    src: "/screens/notch-storage.png",
    title: "Read-only until you say so",
    body: "Caches, logs, Xcode build files and old downloads are listed first. Nothing changes until you choose and confirm.",
  },
  {
    id: "simulate",
    label: "Simulate",
    src: "/screens/notch-simulate.png",
    title: "How the four choices feel",
    body: "An illustration, labelled as one. It shows the idea of the choices, not a measurement of your apps.",
  },
  {
    id: "settings",
    label: "Settings",
    src: "/screens/notch-settings.png",
    title: "Everything in one place",
    body: "Window mode, advanced mode, login, updates and pausing. Each switch says what it does before you turn it on.",
  },
  {
    id: "guide",
    label: "Guide",
    src: "/screens/notch-guide.png",
    title: "The four choices, explained",
    body: "A short guide to Boost, Normal, Yield and Eco, written for people who have never looked at a process list.",
  },
] as const;

export function NotchGallery() {
  const [index, setIndex] = useState(0);
  const current = screens[index];

  function onKey(event: React.KeyboardEvent<HTMLDivElement>) {
    if (event.key !== "ArrowRight" && event.key !== "ArrowLeft") return;
    event.preventDefault();
    const step = event.key === "ArrowRight" ? 1 : -1;
    const next = (index + step + screens.length) % screens.length;
    setIndex(next);
    document.getElementById(`screen-tab-${screens[next].id}`)?.focus();
  }

  return (
    <section id="screens" className="relative mx-auto max-w-6xl scroll-mt-20 px-6 py-20 md:py-28">
      <div className="pointer-events-none absolute inset-x-0 top-10 -z-10 mx-auto h-[70%] max-w-4xl rounded-full bg-perf/10 blur-3xl" aria-hidden />
      <div className="text-center">
        <p className="text-sm font-medium tracking-wide text-perf">Real screenshots</p>
        <h2 className="text-balance mx-auto mt-4 max-w-3xl text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1.06] tracking-[-0.035em]">
          This is the notch. <span className="text-zinc-400">Nothing mocked up.</span>
        </h2>
        <p className="mx-auto mt-5 max-w-xl text-base leading-relaxed text-zinc-400">
          Taken from Coremium running on a MacBook Pro with an M3 Pro, unedited. The numbers on your Mac will be different.
        </p>
      </div>

      <div role="tablist" aria-label="Notch screens" onKeyDown={onKey}
        className="mx-auto mt-10 flex max-w-full flex-wrap justify-center gap-1.5 rounded-2xl bg-white/[0.04] p-1.5 ring-1 ring-inset ring-white/10">
        {screens.map((screen, i) => {
          const selected = i === index;
          return (
            <button key={screen.id} id={`screen-tab-${screen.id}`} type="button" role="tab" aria-selected={selected}
              aria-controls="screen-panel" tabIndex={selected ? 0 : -1} onClick={() => setIndex(i)}
              className={cn("min-h-11 rounded-xl px-4 text-sm font-medium transition-colors",
                selected ? "bg-white text-black" : "text-zinc-300 hover:bg-white/10 hover:text-white")}>
              {screen.label}
            </button>
          );
        })}
      </div>

      <div id="screen-panel" role="tabpanel" aria-labelledby={`screen-tab-${current.id}`} className="mt-8">
        <div className="relative mx-auto max-w-4xl">
          <div className="absolute -inset-6 -z-10 rounded-[40px] bg-gradient-to-br from-perf/25 via-eff/10 to-mint/20 opacity-60 blur-2xl" aria-hidden />
          <div className="overflow-hidden rounded-[28px] bg-black ring-1 ring-inset ring-white/12 shadow-[0_40px_120px_-30px_rgba(98,228,255,0.35)]">
            <Image key={current.src} src={current.src} alt={`The Coremium notch, ${current.label} tab: ${current.title.toLowerCase()}.`}
              width={1560} height={976} sizes="(min-width: 896px) 896px, 100vw" priority={index === 0}
              className="h-auto w-full rise" />
          </div>
        </div>
        <div className="mx-auto mt-8 max-w-xl text-center">
          <h3 className="text-xl font-semibold tracking-[-0.02em] text-white">{current.title}</h3>
          <p className="mt-2 text-[15px] leading-relaxed text-zinc-400">{current.body}</p>
        </div>
      </div>
    </section>
  );
}
