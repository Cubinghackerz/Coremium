import TechText from "@/components/tech-text";

/* The closing wordmark. It only animates while it is on screen, and it stops when you scroll away. */
export function Wordmark() {
  return (
    <section aria-label="Coremium wordmark" className="mx-auto max-w-6xl px-6 pb-10 pt-6">
      <div className="h-[240px] md:h-[360px]">
        <TechText text="Coremium" fontWeight={600} fontSize={220} letterSpacing={-0.04} reveal="letter" specks={12} sweep dashLength={4} dashGap={2} />
      </div>
      <p className="mt-2 text-center text-sm text-zinc-400">Hover the letters. Drag one to see it move. Nothing here measures your Mac.</p>
    </section>
  );
}
