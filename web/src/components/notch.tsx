"use client";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import Image from "next/image";
import { useEffect, useState } from "react";

/* The site's own notch. It sits in the middle of the menu bar like the real one. While the page is at the top it shows the kind of
   one-line decision Coremium makes, and on hover it opens a small preview. Decorative: every link it hints at is also in the bar. */
const activities = [
  { app: "Minecraft", mode: "Gaming" },
  { app: "Xcode", mode: "Coding" },
  { app: "Final Cut Pro", mode: "Creator" },
  { app: "Ollama", mode: "Local AI" },
];

const BAR = 56;
const spring = { type: "spring", stiffness: 420, damping: 38, mass: 0.9 } as const;
const cores = [0.82, 0.74, 0.88, 0.69, 0.78, 0.52, 0.61, 0.47, 0.58, 0.44, 0.5];

export function Notch() {
  const reduce = useReducedMotion();
  const [wide, setWide] = useState(false);
  const [roomy, setRoomy] = useState(false);
  const [atTop, setAtTop] = useState(true);
  const [hover, setHover] = useState(false);
  const [index, setIndex] = useState(0);
  const [showing, setShowing] = useState(false);

  useEffect(() => {
    const media = window.matchMedia("(min-width: 768px)");
    const large = window.matchMedia("(min-width: 1024px)");
    const update = () => {
      setWide(media.matches);
      setRoomy(large.matches);
    };
    update();
    media.addEventListener("change", update);
    large.addEventListener("change", update);
    const onScroll = () => setAtTop(window.scrollY < 60);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      media.removeEventListener("change", update);
      large.removeEventListener("change", update);
      window.removeEventListener("scroll", onScroll);
    };
  }, []);

  /* One decision every few seconds, only at the top of the page, only where the menu bar has room, never while hovered. */
  useEffect(() => {
    if (!roomy || !atTop || hover || reduce) {
      setShowing(false);
      return undefined;
    }
    let shown = false;
    const first = window.setTimeout(() => {
      shown = true;
      setShowing(true);
    }, 1400);
    const timer = window.setInterval(() => {
      if (document.hidden) return;
      shown = !shown;
      if (shown) setIndex((i) => (i + 1) % activities.length);
      setShowing(shown);
    }, 2600);
    return () => {
      window.clearTimeout(first);
      window.clearInterval(timer);
    };
  }, [roomy, atTop, hover, reduce]);

  const base = wide ? 200 : 124;
  const open = hover && wide;
  const width = open ? 460 : showing ? base + 300 : base;
  const height = open ? 230 : BAR;
  const activity = activities[index];

  return (
    <div className="absolute left-1/2 top-0 -translate-x-1/2" aria-hidden onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}>
      <motion.div
        initial={false}
        animate={{ width, height, borderBottomLeftRadius: open ? 30 : 14, borderBottomRightRadius: open ? 30 : 14 }}
        transition={reduce ? { duration: 0 } : spring}
        className="relative overflow-visible bg-black ring-1 ring-inset ring-white/[0.08]"
        style={{ width: base, height: BAR }}
      >
        <span className="absolute -left-[10px] top-0 size-[10px] bg-[radial-gradient(circle_at_0_100%,transparent_9.5px,#000_10px)]" />
        <span className="absolute -right-[10px] top-0 size-[10px] bg-[radial-gradient(circle_at_100%_100%,transparent_9.5px,#000_10px)]" />

        <div className="absolute inset-0 overflow-hidden rounded-[inherit]">
          <AnimatePresence>
            {showing && !open ? (
              <motion.div
                key={activity.app}
                initial={{ opacity: 0, filter: "blur(4px)" }}
                animate={{ opacity: 1, filter: "blur(0px)" }}
                exit={{ opacity: 0, filter: "blur(4px)" }}
                transition={{ duration: 0.3, delay: 0.08 }}
                className="absolute inset-0 flex items-center justify-between px-5 text-[14px] font-medium"
              >
                <span className="flex w-[132px] items-center gap-2 truncate text-white">
                  <span className="size-2 shrink-0 rounded-full bg-boost shadow-[0_0_10px_rgba(255,194,103,0.8)]" />
                  {activity.app}
                </span>
                <span className="w-[132px] truncate text-right text-zinc-400">{activity.mode} mode</span>
              </motion.div>
            ) : null}
          </AnimatePresence>

          <AnimatePresence>
            {open ? (
              <motion.div
                initial={{ opacity: 0, y: -6, filter: "blur(6px)" }}
                animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                exit={{ opacity: 0, transition: { duration: 0.1 } }}
                transition={{ duration: 0.3, delay: 0.12 }}
                className="absolute inset-x-0 top-[56px] px-6 pb-5 pt-3"
              >
                <div className="flex items-center justify-between">
                  <span className="flex items-center gap-2 text-[13px] font-semibold text-white">
                    <Image src="/brand/mark-white.png" alt="" width={16} height={17} /> Coremium
                  </span>
                  <span className="rounded-full bg-white px-2.5 py-0.5 text-[11px] font-semibold text-black">Automatic</span>
                </div>
                <p className="mt-3 text-[12.5px] leading-snug text-zinc-300">
                  <span className="mr-1.5 inline-block size-1.5 rounded-full bg-boost align-middle" />
                  Automatic chose Gaming. Minecraft is protected; 18 background processes at lower priority.
                </p>
                <div className="mt-3 flex h-10 items-end gap-1">
                  {cores.map((load, i) => (
                    <span key={i} className={i < 5 ? "flex-1 rounded-[3px] bg-perf/80" : "flex-1 rounded-[3px] bg-eff/80"} style={{ height: `${load * 100}%` }} />
                  ))}
                </div>
                <p className="mt-2 flex justify-between text-[11px] text-zinc-500">
                  <span>5 performance cores</span>
                  <span>Illustration</span>
                  <span>6 efficiency cores</span>
                </p>
              </motion.div>
            ) : null}
          </AnimatePresence>
        </div>
      </motion.div>
    </div>
  );
}
