import CardSwap from "@/components/card-swap";
import ScrollExpand from "@/components/scroll-expand";

const screens = [
  { title: "Apps", image: "/screens/notch-apps.png", alt: "The Apps tab: each running app with its choice." },
  { title: "Advanced", image: "/screens/notch-apps-advanced.png", alt: "Advanced mode: per-core load and the numbers behind each choice." },
  { title: "System", image: "/screens/notch-system.png", alt: "The System tab: memory, swap and the apps using the most." },
  { title: "Storage", image: "/screens/notch-storage.png", alt: "The Storage tab: read-only until you confirm." },
  { title: "Settings", image: "/screens/notch-settings.png", alt: "The Settings tab: window mode, advanced mode and the rest." },
];

/* Scroll to open the Advanced capture, then a stack of every view. Both pause when they are off screen. */
export function Showcase() {
  return (
    <>
      <section aria-label="Scroll to expand the Advanced view" className="h-[290svh] w-full">
          <ScrollExpand
            src="/screens/notch-apps-advanced.png"
            alt="The Coremium notch in Advanced mode, with per-core load and each app's choice."
            title="The numbers, on purpose"
            scrollHint="Scroll"
            useWindowScroll
            startWidth={62}
            startHeight={66}
            startRadius={28}
            scrollDistance={1.4}
            holdDistance={0.5}
            mediaZoom={1.15}
          >
            <div className="max-w-xl">
              <h2 className="text-balance text-[clamp(28px,4vw,48px)] font-semibold leading-[1.05] tracking-[-0.03em] text-white">
                Advanced mode shows what it measured.
              </h2>
              <p className="mt-4 text-base leading-relaxed text-zinc-300">
                Per-core load, memory pressure, swap, and the choice behind each app. Turn it off to keep it simple.
              </p>
            </div>
          </ScrollExpand>
      </section>
      <section aria-labelledby="stack-heading" className="mx-auto max-w-6xl px-6 py-20 md:py-28">
        <div className="text-center">
          <p className="text-sm font-medium tracking-wide text-perf">Every view</p>
          <h2 id="stack-heading" className="text-balance mx-auto mt-4 max-w-3xl text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1.04] tracking-[-0.035em]">
            One notch. <span className="text-zinc-400">Five views.</span>
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-base leading-relaxed text-zinc-400">Drag the top card, or use the arrow keys. Real captures from one Mac.</p>
        </div>
        <div className="mt-12 h-[420px] md:h-[520px]">
          <CardSwap items={screens} width={520} height={330} cardDistance={64} verticalDistance={56} depth={70} delay={4500} />
        </div>
      </section>
    </>
  );
}
