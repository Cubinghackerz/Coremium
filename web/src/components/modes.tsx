"use client";
import { Brain, Code2, Gamepad2, Palette, Scale, Wand2, type LucideIcon } from "lucide-react";
import { motion, useReducedMotion } from "motion/react";

const modes: { name: string; icon: LucideIcon; line: string }[] = [
  { name: "Balanced", icon: Scale, line: "Only your per-app choices apply." },
  { name: "Gaming", icon: Gamepad2, line: "Games first. Creative tools, browsers and chat step aside." },
  { name: "Automatic", icon: Wand2, line: "Follows what you're doing and switches by itself." },
  { name: "Creator", icon: Palette, line: "Video, audio, 3D and photo get the fast cores." },
  { name: "Coding", icon: Code2, line: "Editors, terminals and builds first." },
  { name: "Local AI", icon: Brain, line: "Models, image generation and VMs first." },
];

export function Modes() {
  const reduce = useReducedMotion();
  return (
    <section className="relative px-6 py-24 md:py-32">
      <div className="mx-auto max-w-6xl">
        <h2 className="text-balance mx-auto max-w-3xl text-center text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1.02] tracking-[-0.035em]">
          <span className="text-zinc-400">One mode for what you&apos;re doing.</span>{" "}
          <span className="text-white">Or let it pick.</span>
        </h2>
        <ul className="mx-auto mt-14 grid max-w-4xl grid-cols-2 gap-x-4 gap-y-10 sm:grid-cols-3 md:grid-cols-6 md:gap-x-6">
          {modes.map(m => {
            const selected = m.name === "Automatic";
            return (
              <motion.li
                key={m.name}
                whileHover={reduce ? undefined : { y: -4 }}
                transition={{ type: "spring", stiffness: 380, damping: 26 }}
                className="flex flex-col items-center text-center"
              >
                <div
                  className={`grid size-20 place-items-center rounded-2xl ring-1 ring-inset transition-colors md:size-24 ${
                    selected ? "bg-white text-black ring-white" : "bg-white/[0.05] text-zinc-200 ring-white/10"
                  }`}
                >
                  <m.icon className="size-7" strokeWidth={1.6} aria-hidden />
                </div>
                <span className="mt-4 text-[15px] font-medium text-white">{m.name}</span>
                {selected ? <span className="mt-1 text-xs text-zinc-400">Recommended</span> : null}
                <span className="mt-2 hidden text-[13px] leading-snug text-zinc-400 md:block">{m.line}</span>
                <span className="sr-only">{m.line}</span>
              </motion.li>
            );
          })}
        </ul>
        <p className="mx-auto mt-14 max-w-xl text-center text-zinc-400">
          Gaming, Creator, Coding and Local AI each protect their own kind of app and move the others aside. Automatic watches what&apos;s in front and
          chooses for you, then tells you why.
        </p>
      </div>
    </section>
  );
}
