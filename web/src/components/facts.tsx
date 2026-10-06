const rows: [string, string, string][] = [
  ["Closes apps", "Never", "It only changes how the system schedules them. Quit Coremium and everything is restored."],
  ["Touches", "Your own apps", "Only processes owned by your user. No root helper, no system processes."],
  ["Network", "One update check a day", "Asks GitHub whether a newer version exists. No telemetry, no account. Turn it off in Settings."],
  ["Cost to run", "Visible in Insights", "Coremium shows its own CPU use. Cost varies with your running apps and whether the panel is open."],
  ["Price", "Free, MIT license", "Read the source and build it yourself."],
  ["Runs on", "macOS 13 and later", "Apple Silicon and Intel. Tested on macOS 27 with an M3 Pro so far. A Windows 10 and 11 beta is also available."],
];

export function Facts() {
  return (
    <section id="facts" className="mx-auto max-w-5xl px-6 py-24 md:py-32">
      <h2 className="text-balance text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1.02] tracking-[-0.035em]">
        <span className="text-zinc-400">Small, safe, and honest</span> <span className="text-white">about what it does.</span>
      </h2>
      <dl className="mt-14 divide-y divide-line border-y border-line">
        {rows.map(([k, v, d]) => (
          <div key={k} className="grid gap-2 py-6 md:grid-cols-[1fr_1.1fr_2fr] md:items-baseline md:gap-8">
            <dt className="text-[15px] text-zinc-400">{k}</dt>
            <dd className="text-[22px] font-semibold tracking-[-0.02em] text-white">{v}</dd>
            <dd className="text-[15.5px] leading-relaxed text-zinc-400">{d}</dd>
          </div>
        ))}
      </dl>
      <p className="mt-8 max-w-2xl text-[15px] leading-relaxed text-zinc-400">
        macOS has no public way to raise an app above normal priority, so Boost works by clearing the way for it. If your Mac isn&apos;t overloaded there is
        little to move. Coremium makes no claims about frame rates, battery life or temperature, because it can&apos;t measure them.
      </p>
    </section>
  );
}
