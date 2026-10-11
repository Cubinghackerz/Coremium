"use client";
import { motion, useMotionValueEvent, useReducedMotion, useScroll, useTransform, type MotionValue } from "motion/react";
import Image from "next/image";
import { useRef, useState } from "react";
import { CopyLine } from "@/components/install";
import { cn, DOWNLOADS, INSTALL_CMD } from "@/lib/utils";

/* Real captures of the notch panel, taken on one Mac (M3 Pro). Unedited. Numbers differ on every Mac. */
const screens = [
  { id: "apps", label: "Apps", src: "/screens/notch-apps.png", title: "One choice per app", body: "Every running app gets Boost, Normal, Yield or Eco. The line under the modes says what Coremium changed and why." },
  { id: "advanced", label: "Advanced", src: "/screens/notch-apps-advanced.png", title: "The numbers behind it", body: "Per-core load, memory pressure, swap and GPU use next to each decision. Turn it off to keep things simple." },
  { id: "system", label: "System", src: "/screens/notch-system.png", title: "Memory, in plain words", body: "Pressure, swap and the apps using the most memory. Coremium never quits anything on its own." },
  { id: "storage", label: "Storage", src: "/screens/notch-storage.png", title: "Read-only until you say so", body: "Caches, logs, build files and old downloads are listed first. Nothing changes until you choose and confirm." },
  { id: "settings", label: "Settings", src: "/screens/notch-settings.png", title: "Every switch explains itself", body: "Window mode, Advanced mode, login, updates and pausing. Each one says what it does before you turn it on." },
] as const;

/* Scroll timeline, as fractions of the pinned stage: the headline leaves, the notch opens, five screens, the notch closes. */
const OPEN = [0.03, 0.2] as const;
const TABS = [0.22, 0.86] as const;
const CLOSE = [0.88, 0.97] as const;
const tabAt = (p: number) => Math.min(screens.length - 1, Math.max(0, Math.floor(((p - TABS[0]) / (TABS[1] - TABS[0])) * screens.length)));

const easeOut = (x: number) => 1 - Math.pow(1 - x, 3);
const range = (v: number, a: number, b: number) => Math.min(1, Math.max(0, (v - a) / (b - a)));

function Headline({ className }: { className?: string }) {
  return (
    <div className={cn("mx-auto max-w-4xl px-6 text-center", className)}>
      <h1 className="text-balance text-[clamp(40px,7vw,88px)] font-semibold leading-[1] tracking-[-0.045em]">
        Give the app you&apos;re using <span className="text-white/55">more room to work.</span>
      </h1>
      <p className="text-pretty mx-auto mt-6 max-w-xl text-[17px] leading-relaxed text-zinc-300 md:text-lg">
        Coremium lives in your Mac&apos;s notch. While you play, create, code or run local AI, it lowers the priority of busy background apps. Nothing
        gets closed.
      </p>
      <div className="mx-auto mt-8 max-w-2xl text-left">
        <CopyLine text={INSTALL_CMD} label="macOS install command" />
      </div>
      <p className="mt-2 text-sm text-zinc-400">Free · Open source · No account · v{DOWNLOADS.mac.version} · macOS 13+ · Apple Silicon &amp; Intel</p>
    </div>
  );
}

function Caption({ active, onPick }: { active: number; onPick: (index: number) => void }) {
  const current = screens[active];
  return (
    <div className="mx-auto max-w-2xl px-6 text-center">
      <div role="tablist" aria-label="Notch screens" className="inline-flex flex-wrap justify-center gap-1 rounded-[22px] bg-white/[0.06] sm:rounded-full p-1 ring-1 ring-inset ring-white/10 backdrop-blur-md">
        {screens.map((screen, i) => (
          <button
            key={screen.id}
            type="button"
            role="tab"
            aria-selected={i === active}
            onClick={() => onPick(i)}
            className={cn("relative rounded-full px-3.5 py-1.5 text-[13px] font-medium transition-colors md:px-4", i === active ? "text-black" : "text-zinc-300 hover:text-white")}
          >
            {i === active ? <motion.span layoutId="screen-pill" className="absolute inset-0 rounded-full bg-white" transition={{ type: "spring", stiffness: 500, damping: 40 }} /> : null}
            <span className="relative">{screen.label}</span>
          </button>
        ))}
      </div>
      <motion.div key={current.id} initial={{ opacity: 0, y: 8, filter: "blur(6px)" }} animate={{ opacity: 1, y: 0, filter: "blur(0px)" }} transition={{ duration: 0.4 }}>
        <h2 className="mt-5 text-xl font-semibold tracking-[-0.02em] text-white md:text-2xl">{current.title}</h2>
        <p className="text-pretty mx-auto mt-2 max-w-lg text-[15px] leading-relaxed text-zinc-400">{current.body}</p>
      </motion.div>
    </div>
  );
}

function Screens({ active, scale }: { active: number; scale?: MotionValue<number> }) {
  return (
    <motion.div className="relative h-full w-full origin-top" style={scale ? { scale } : undefined}>
      {screens.map((screen, i) => (
        <Image
          key={screen.id}
          src={screen.src}
          alt={`The Coremium notch panel, ${screen.label} tab: ${screen.title.toLowerCase()}.`}
          fill
          sizes="(min-width: 1080px) 1040px, 100vw"
          priority={i === 0}
          className={cn("object-cover object-top transition-[opacity,filter] duration-500", i === active ? "opacity-100 blur-0" : "opacity-0 blur-sm")}
        />
      ))}
    </motion.div>
  );
}

/* With reduced motion there is no pinned stage: the headline, then the open panel with plain tabs. */
function StaticHero() {
  const [active, setActive] = useState(0);
  return (
    <section id="top" className="relative overflow-hidden bg-black pb-24 pt-[calc(var(--bar)+96px)]">
      <Headline />
      <div id="screens" className="relative mx-auto mt-16 aspect-[1560/976] w-[min(1040px,calc(100vw-24px))] overflow-hidden rounded-b-[32px] rounded-t-[18px] bg-black">
        <Screens active={active} />
      </div>
      <div className="mt-8">
        <Caption active={active} onPick={setActive} />
      </div>
    </section>
  );
}

export function Hero() {
  const reduce = useReducedMotion();
  const ref = useRef<HTMLElement>(null);
  const { scrollYProgress: p } = useScroll({ target: ref, offset: ["start start", "end end"] });
  const [active, setActive] = useState(0);
  const [captions, setCaptions] = useState(false);

  useMotionValueEvent(p, "change", (v) => {
    setActive(tabAt(v));
    setCaptions(v > OPEN[1] - 0.02 && v < CLOSE[0]);
  });

  /* t is how open the notch is: 0 is the notch in the menu bar, 1 is the full panel. */
  const t = useTransform(p, (v) => {
    if (v <= OPEN[0]) return 0;
    if (v < OPEN[1]) return easeOut((v - OPEN[0]) / (OPEN[1] - OPEN[0]));
    if (v <= CLOSE[0]) return 1;
    if (v < CLOSE[1]) return 1 - easeOut((v - CLOSE[0]) / (CLOSE[1] - CLOSE[0]));
    return 0;
  });
  const clipPath = useTransform(t, (v) => {
    const k = 1 - v;
    const r = 14 + 20 * v;
    return `inset(0px calc((50% - var(--nw) / 2) * ${k}) calc((100% - var(--bar)) * ${k}) calc((50% - var(--nw) / 2) * ${k}) round 0px 0px ${r}px ${r}px)`;
  });
  /* Function transforms on purpose: motion hands plain range maps of opacity and filter to the browser's scroll timeline,
     which does not hold the end value past the range, so the headline came back near the end of the stage. */
  const contentScale = useTransform(t, (v) => 0.9 + 0.1 * v);
  const headOpacity = useTransform(p, (v) => 1 - range(v, 0, 0.12));
  const headY = useTransform(p, (v) => 60 * range(v, 0, 0.14));
  const headBlur = useTransform(p, (v) => `blur(${10 * range(v, 0, 0.12)}px)`);
  const hintOpacity = useTransform(p, (v) => 1 - range(v, 0, 0.04));

  if (reduce) return <StaticHero />;

  function pick(index: number) {
    const el = ref.current;
    if (!el) return;
    const span = el.offsetHeight - window.innerHeight;
    const at = TABS[0] + ((index + 0.5) / screens.length) * (TABS[1] - TABS[0]);
    window.scrollTo({ top: el.offsetTop + span * at, behavior: "smooth" });
  }

  return (
    <section id="top" ref={ref} className="relative h-[460svh] [--nw:124px] [--pad:40px] md:[--nw:200px] md:[--pad:28px]">
      <div id="screens" className="absolute top-[30%]" aria-hidden />
      <div className="sticky top-0 h-svh overflow-hidden bg-black [--pw:min(1040px,calc(100vw-24px),calc((100svh-var(--bar)-200px)*1.598))]">

        <motion.div
          className="absolute left-1/2 top-0 h-[calc(var(--pw)/1.598+var(--pad))] w-[var(--pw)] -translate-x-1/2 overflow-hidden bg-black will-change-[clip-path]"
          style={{ clipPath }}
        >
          <div className="absolute inset-x-0 bottom-0 top-[var(--pad)]">
            <Screens active={active} scale={contentScale} />
          </div>
          <div className="pointer-events-none absolute inset-0 rounded-b-[34px] ring-1 ring-inset ring-white/12" aria-hidden />
        </motion.div>

        <motion.div
          className="absolute inset-x-0 top-1/2 -translate-y-[44%]"
          style={{ opacity: headOpacity, y: headY, filter: headBlur, pointerEvents: captions ? "none" : "auto" }}
        >
          <Headline />
        </motion.div>

        <motion.div className="absolute inset-x-0 bottom-7 flex flex-col items-center gap-2 text-[13px] text-zinc-400" style={{ opacity: hintOpacity }} aria-hidden>
          Scroll to open the notch
          <span className="h-8 w-px overflow-hidden bg-white/10">
            <motion.span className="block h-3 w-px bg-white" animate={{ y: [-12, 32] }} transition={{ duration: 1.6, repeat: Infinity, ease: "easeInOut" }} />
          </span>
        </motion.div>

        <motion.div
          className="absolute inset-x-0 top-[calc(var(--pw)/1.598+var(--pad)+24px)]"
          initial={false}
          animate={{ opacity: captions ? 1 : 0, y: captions ? 0 : 12 }}
          transition={{ duration: 0.35 }}
          style={{ pointerEvents: captions ? "auto" : "none" }}
        >
          <Caption active={active} onPick={pick} />
        </motion.div>
      </div>
    </section>
  );
}
