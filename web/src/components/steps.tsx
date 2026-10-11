const steps = [
  {
    title: "Install",
    body: "Paste one line into Terminal. The installer checks the download against its published checksum, then puts Coremium in Applications.",
  },
  {
    title: "Open it",
    body: "Coremium lives in the notch. Hover over it, or click the chip icon in the menu bar. Hide it whenever you like.",
  },
  {
    title: "Let Automatic work",
    body: "It follows the app in front of you and moves busy background apps aside. Everything you have open stays open.",
  },
];

export function Steps() {
  return (
    <section className="mx-auto max-w-6xl px-6 py-20 md:py-28">
      <div className="text-center">
        <p className="text-sm font-medium tracking-wide text-perf">Three steps</p>
        <h2 className="text-balance mx-auto mt-4 max-w-3xl text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1.04] tracking-[-0.035em]">
          No setup. <span className="text-zinc-400">No account.</span>
        </h2>
      </div>
      <ol className="mt-14 grid gap-5 md:grid-cols-3">
        {steps.map((step, index) => (
          <li key={step.title} className="rounded-[28px] bg-white/[0.035] p-7 ring-1 ring-inset ring-white/10 md:p-8">
            <span className="flex size-9 items-center justify-center rounded-full bg-white text-sm font-semibold text-black">{index + 1}</span>
            <h3 className="mt-6 text-xl font-semibold tracking-[-0.02em] text-white">{step.title}</h3>
            <p className="mt-3 text-[15px] leading-relaxed text-zinc-400">{step.body}</p>
          </li>
        ))}
      </ol>
    </section>
  );
}
