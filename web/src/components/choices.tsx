"use client";
import { CloudIcon, GameController03Icon, Globe02Icon, Message01Icon, PauseIcon, PlayIcon } from "@hugeicons/core-free-icons";
import { Icon, type IconSvgElement } from "@/components/icon";
import { AnimatePresence, motion } from "motion/react";
import { useState } from "react";
import { cn } from "@/lib/utils";

type Choice = "Boost" | "Normal" | "Yield" | "Eco";
const order: Choice[] = ["Boost", "Normal", "Yield", "Eco"];

const look: Record<Choice, { on: string; text: string }> = {
  Boost: { on: "bg-boost text-black", text: "text-boost" },
  Normal: { on: "text-white ring-1 ring-inset ring-white/70", text: "text-white" },
  Yield: { on: "bg-perf text-black", text: "text-perf" },
  Eco: { on: "bg-mint text-black", text: "text-mint" },
};

const meaning: Record<Choice, (app: string) => string> = {
  Boost: (app) => `${app} is protected while you use it. Apps set to Yield step aside for it.`,
  Normal: (app) => `${app} is left alone. macOS schedules it as usual.`,
  Yield: (app) => `${app} steps aside to the efficiency cores while something else is boosted.`,
  Eco: (app) => `${app} stays on the efficiency cores unless you're using it.`,
};

/* Illustrative apps and readings, in the layout of the real Apps tab. */
const apps: { name: string; kind: string; icon: IconSvgElement; tint: string; cpu: string; initial: Choice }[] = [
  { name: "Minecraft", kind: "Games", icon: GameController03Icon, tint: "bg-boost/15 text-boost", cpu: "42%", initial: "Boost" },
  { name: "Google Chrome", kind: "Browsers", icon: Globe02Icon, tint: "bg-perf/15 text-perf", cpu: "6%", initial: "Yield" },
  { name: "Discord", kind: "Chat", icon: Message01Icon, tint: "bg-eff/15 text-eff", cpu: "3%", initial: "Yield" },
  { name: "Dropbox", kind: "Sync and backup", icon: CloudIcon, tint: "bg-mint/15 text-mint", cpu: "1%", initial: "Eco" },
];

type Entry = { id: number; time: string; text: string };
const clock = () => new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });

export function Choices() {
  const [picks, setPicks] = useState<Choice[]>(apps.map((a) => a.initial));
  const [focus, setFocus] = useState<{ app: string; choice: Choice }>({ app: "Minecraft", choice: "Boost" });
  const [paused, setPaused] = useState(false);
  const [log, setLog] = useState<Entry[]>([]);

  const add = (text: string) => setLog((l) => [{ id: Date.now() + Math.random(), time: clock(), text }, ...l].slice(0, 4));

  function choose(index: number, choice: Choice) {
    setPicks((p) => p.map((c, i) => (i === index ? choice : c)));
    setFocus({ app: apps[index].name, choice });
    if (paused) setPaused(false);
    add(`${apps[index].name} set to ${choice}.`);
  }

  function togglePause() {
    setPaused((v) => !v);
    add(paused ? "Resumed. Your choices apply again." : "Paused. Every app is back to macOS defaults.");
  }

  return (
    <section aria-labelledby="choices-heading" className="mx-auto max-w-6xl px-5 py-24 md:px-6 md:py-32">
      <h2 id="choices-heading" className="text-balance max-w-3xl text-[clamp(34px,5vw,64px)] font-semibold leading-[1] tracking-[-0.04em]">
        Four choices for every app. <span className="text-white/45">Yours always beat the mode.</span>
      </h2>
      <p className="text-pretty mt-6 max-w-xl text-[16px] leading-relaxed text-zinc-400">
        Defaults come from what each app is, so most people never touch them. Try it: this is the Apps tab, with made-up apps and readings.
      </p>

      <div className="mt-14 grid gap-6 lg:grid-cols-[1.45fr_1fr]">
        <div className="rounded-[28px] bg-ink p-2 ring-1 ring-inset ring-white/10 md:p-3">
          <ul className="space-y-1.5">
            {apps.map((app, i) => {
              const current = paused ? "Normal" : picks[i];
              return (
                <li key={app.name} className="flex flex-col gap-3 rounded-[20px] bg-white/[0.035] p-3.5 sm:flex-row sm:items-center sm:justify-between md:p-4">
                  <div className="flex min-w-0 items-center gap-3">
                    <span className={cn("grid size-10 shrink-0 place-items-center rounded-[11px]", app.tint)}>
                      <Icon icon={app.icon} className="size-5" />
                    </span>
                    <div className="min-w-0">
                      <p className="truncate text-[16px] font-semibold text-white">{app.name}</p>
                      <p className="text-[13px] text-zinc-500">
                        {app.kind} · <span className="font-mono tabular-nums text-zinc-400">{app.cpu}</span>
                      </p>
                    </div>
                  </div>
                  <div role="radiogroup" aria-label={`Choice for ${app.name}`} className="flex gap-1">
                    {order.map((choice) => {
                      const on = current === choice;
                      return (
                        <button
                          key={choice}
                          type="button"
                          role="radio"
                          aria-checked={on}
                          onClick={() => choose(i, choice)}
                          className={cn(
                            "h-8 rounded-full px-3 text-[13px] font-semibold transition-[background-color,color,box-shadow] duration-200",
                            on ? look[choice].on : "bg-white/[0.05] text-zinc-400 hover:bg-white/10 hover:text-white",
                          )}
                        >
                          {choice}
                        </button>
                      );
                    })}
                  </div>
                </li>
              );
            })}
          </ul>
          <div className="mt-2 flex items-center justify-between gap-4 px-3 py-2">
            <p className="text-[13px] text-zinc-500">{paused ? "Paused: macOS defaults for every app." : "Illustration. Nothing here touches your Mac."}</p>
            <button
              type="button"
              onClick={togglePause}
              aria-pressed={paused}
              className="inline-flex h-9 shrink-0 items-center gap-2 rounded-full bg-white/[0.07] px-4 text-[13px] font-semibold text-white ring-1 ring-inset ring-white/10 transition-colors hover:bg-white/[0.12]"
            >
              <Icon icon={paused ? PlayIcon : PauseIcon} className="size-3.5" strokeWidth={2} />
              {paused ? "Resume" : "Pause"}
            </button>
          </div>
        </div>

        <div className="flex flex-col rounded-[28px] p-2 lg:p-4">
          <div aria-live="polite" className="min-h-[170px]">
            <AnimatePresence mode="wait">
              <motion.div
                key={paused ? "paused" : `${focus.app}-${focus.choice}`}
                initial={{ opacity: 0, y: 10, filter: "blur(8px)" }}
                animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                exit={{ opacity: 0, y: -6, filter: "blur(4px)" }}
                transition={{ duration: 0.35, ease: [0.22, 1, 0.36, 1] }}
              >
                <p className={cn("text-[56px] font-semibold leading-none tracking-[-0.045em] md:text-[72px]", paused ? "text-zinc-300" : look[focus.choice].text)}>
                  {paused ? "Paused" : focus.choice}
                </p>
                <p className="text-pretty mt-4 max-w-sm text-[17px] leading-relaxed text-zinc-300">
                  {paused ? "Every app is back to macOS defaults at once. Quitting Coremium does the same." : meaning[focus.choice](focus.app)}
                </p>
              </motion.div>
            </AnimatePresence>
          </div>
          <div className="mt-8 border-t border-white/10 pt-5">
            <p className="text-[13px] font-medium text-zinc-400">What Coremium says</p>
            {log.length === 0 ? (
              <p className="mt-3 text-[14px] text-zinc-500">Change a choice and the reason shows up here, as it does in the notch.</p>
            ) : (
              <ol className="mt-3 space-y-2">
                <AnimatePresence initial={false}>
                  {log.map((entry, i) => (
                    <motion.li
                      key={entry.id}
                      layout
                      initial={{ opacity: 0, x: -8 }}
                      animate={{ opacity: i === 0 ? 1 : 0.5, x: 0 }}
                      exit={{ opacity: 0 }}
                      transition={{ duration: 0.3 }}
                      className="flex gap-3 text-[14px] text-zinc-200"
                    >
                      <span className="shrink-0 font-mono text-[12px] leading-[21px] tabular-nums text-zinc-500">{entry.time}</span>
                      {entry.text}
                    </motion.li>
                  ))}
                </AnimatePresence>
              </ol>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
