import CardSwap from "@/components/card-swap";

const screens = [
  { title: "Apps", image: "/screens/notch-apps.png", alt: "The Apps tab: each running app with its choice." },
  { title: "Advanced", image: "/screens/notch-apps-advanced.png", alt: "Advanced mode: per-core load and the numbers behind each choice." },
  { title: "System", image: "/screens/notch-system.png", alt: "The System tab: memory, swap and the apps using the most." },
  { title: "Storage", image: "/screens/notch-storage.png", alt: "The Storage tab: read-only until you confirm." },
  { title: "Settings", image: "/screens/notch-settings.png", alt: "The Settings tab: window mode, advanced mode and the rest." },
];

/* The labels are the ones Advanced mode prints in the notch. */
const numbers: [string, string][] = [
  ["P cores · E cores", "Average load of each kind of core, from the per-core readings."],
  ["Memory · Mem pressure", "Memory in use, and macOS's own pressure level."],
  ["Swap used", "How much swap is in use right now."],
  ["GPU · renderer · tiler", "Device utilisation, with its renderer and tiler parts."],
  ["Thermal · Power", "The system thermal state, and whether the Mac is on AC power."],
  ["Moved", "How many processes Coremium has moved aside right now."],
];

export function Showcase() {
  return (
    <>
      <section aria-labelledby="numbers-heading" className="mx-auto max-w-6xl px-6 py-20 md:py-28">
        <div className="grid gap-12 md:grid-cols-[1fr_1.1fr] md:items-center">
          <div>
            <h2 id="numbers-heading" className="text-balance mt-4 text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1.04] tracking-[-0.035em]">
              The numbers behind <span className="text-zinc-400">each choice.</span>
            </h2>
            <p className="mt-5 max-w-md text-base leading-relaxed text-zinc-400">
              Turn on Advanced mode and the notch shows what Coremium measured. Every number here is read from this Mac.
            </p>
          </div>
          <dl className="divide-y divide-white/10 border-y border-white/10">
            {numbers.map(([label, body]) => (
              <div key={label} className="grid gap-1 py-5 sm:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)] sm:gap-10">
                <dt className="font-medium text-zinc-100">{label}</dt>
                <dd className="text-sm leading-relaxed text-zinc-400">{body}</dd>
              </div>
            ))}
          </dl>
        </div>
      </section>
      <section aria-labelledby="stack-heading" className="mx-auto max-w-6xl px-6 py-20 md:py-28">
        <div className="text-center">
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
