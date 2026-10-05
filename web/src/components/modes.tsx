"use client";
import { Brain, Code2, Gamepad2, Palette, Scale, Wand2, type LucideIcon } from "lucide-react";
import { motion } from "motion/react";

const modes: { name: string; icon: LucideIcon; line: string; hue: string }[] = [
  { name: "Balanced", icon: Scale, line: "Only your per-app choices apply.", hue: "from-zinc-500/40 to-zinc-800/40" },
  { name: "Gaming", icon: Gamepad2, line: "Games first. Creative tools, browsers and chat step aside.", hue: "from-rose-400/40 to-rose-900/30" },
  { name: "Automatic", icon: Wand2, line: "Follows what you're doing and switches by itself.", hue: "from-cyan-300/60 to-indigo-500/40" },
  { name: "Creator", icon: Palette, line: "Video, audio, 3D and photo get the fast cores.", hue: "from-fuchsia-400/40 to-fuchsia-900/30" },
  { name: "Coding", icon: Code2, line: "Editors, terminals and builds first.", hue: "from-emerald-300/40 to-emerald-900/30" },
  { name: "Local AI", icon: Brain, line: "Models, image generation and VMs first.", hue: "from-violet-300/40 to-violet-900/30" },
];

export function Modes() {
  return (
    <section className="relative px-6 py-24 md:py-32">
      <div className="mx-auto max-w-6xl text-center">
        <h2 className="text-balance mx-auto max-w-3xl text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1.02] tracking-[-0.035em]">
          <span className="text-zinc-500">One mode for what you&apos;re doing.</span>{" "}
          <span className="text-white">Or let it pick.</span>
        </h2>
        <ul className="mx-auto mt-14 flex max-w-4xl flex-wrap items-end justify-center gap-4 md:gap-5">
          {modes.map((m, i) => (
            <motion.li
              key={m.name}
              whileHover={{ y: -8, scale: 1.06 }}
              transition={{ type: "spring", stiffness: 380, damping: 22 }}
              className="group flex w-[104px] flex-col items-center gap-3 md:w-[120px]"
            >
              <div
                className={`grid place-items-center rounded-[26px] bg-gradient-to-b ${m.hue} ring-1 ring-inset ring-white/15 shadow-[0_18px_40px_-18px_rgba(0,0,0,0.9)] ${
                  m.name === "Automatic" ? "size-[104px] md:size-[120px]" : "size-[84px] md:size-[96px]"
                }`}
              >
                <m.icon className={m.name === "Automatic" ? "size-11" : "size-9"} strokeWidth={1.6} aria-hidden />
              </div>
              <span className="text-[15px] font-medium text-white">{m.name}</span>
              <span className="sr-only">{m.line}</span>
              <span aria-hidden className="hidden max-w-[150px] text-center text-[13px] leading-snug text-zinc-500 md:block">
                {i === 2 ? "Recommended" : ""}
              </span>
            </motion.li>
          ))}
        </ul>
        <p className="mx-auto mt-12 max-w-xl text-zinc-400">
          Gaming, Creator, Coding and Local AI each protect their own kind of app and move the others aside. Automatic watches what&apos;s in front and
          chooses for you, then tells you why.
        </p>
      </div>
    </section>
  );
}
