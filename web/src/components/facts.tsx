const rows: [string, string, string][] = [
  ["Never", "closes an app on its own", "It only changes how macOS schedules them. Quit Coremium and everything is restored."],
  ["Only yours", "the processes it touches", "Processes owned by your user. No root helper, no system processes."],
  ["Once a day", "it goes online", "To ask GitHub whether a newer version exists. No telemetry, no account. Turn it off in Settings."],
  ["On screen", "its own cost", "Insights shows Coremium's own CPU use. It varies with your apps and whether the panel is open."],
  ["Free", "MIT license", "Read the source and build it yourself."],
  ["macOS 13+", "Apple Silicon and Intel", "Tested on macOS 27 with an M3 Pro so far. A Windows 10 and 11 beta is also available."],
];

export function Facts() {
  return (
    <section id="facts" className="mx-auto grid max-w-6xl gap-12 px-5 py-24 md:px-6 md:py-36 lg:grid-cols-[0.9fr_1.4fr] lg:gap-20">
      <div className="lg:sticky lg:top-28 lg:self-start">
        <h2 className="text-balance text-[clamp(34px,5vw,64px)] font-semibold leading-[1] tracking-[-0.04em]">
          Small, safe, <span className="text-white/45">and honest about what it does.</span>
        </h2>
        <p className="text-pretty mt-6 max-w-md text-[16px] leading-relaxed text-zinc-400">
          macOS has no public way to raise an app above normal priority, so Coremium clears the way instead. If your Mac isn&apos;t busy, there is little to
          move. It makes no claims about frame rates, battery life or temperature, because it can&apos;t measure them.
        </p>
      </div>
      <dl className="border-t border-white/10">
        {rows.map(([big, small, detail]) => (
          <div key={big} className="grid gap-x-8 gap-y-2 border-b border-white/10 py-7 sm:grid-cols-[1fr_1.2fr]">
            <dt>
              <span className="block text-[30px] font-semibold leading-none tracking-[-0.035em] text-white md:text-[36px]">{big}</span>
              <span className="mt-2 block text-[15px] text-zinc-400">{small}</span>
            </dt>
            <dd className="text-pretty text-[15px] leading-relaxed text-zinc-400 sm:pt-1">{detail}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
