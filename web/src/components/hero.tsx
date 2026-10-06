import Image from "next/image";
import { Download } from "lucide-react";
import { ButtonLink } from "@/components/ui/button";
import { Demo } from "@/components/demo";
import { DOWNLOADS, REPO } from "@/lib/utils";

export function Hero() {
  return (
    <section id="top" className="relative overflow-hidden pt-28 md:pt-36">
      <div className="mx-auto max-w-6xl px-6 text-center">
        <p className="mb-5 text-sm font-medium tracking-wide text-perf">A little breathing room for your Mac.</p>
        <h1 className="text-balance mx-auto max-w-4xl text-[clamp(40px,6.5vw,80px)] font-semibold leading-[1.04] tracking-[-0.04em]">
          Give the app you&apos;re using <span className="text-zinc-400">more room to work.</span>
        </h1>
        <p className="mx-auto mt-6 max-w-xl text-lg leading-relaxed text-zinc-400">
          Coremium lowers background-app priority while you play, create, code, or run local AI. Your other apps stay open.
        </p>
        <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <ButtonLink href={DOWNLOADS.mac.download} size="lg" className="w-full sm:w-auto">
            <Download className="size-5" aria-hidden /> Download for Mac — Free
          </ButtonLink>
          <ButtonLink href="#demo" variant="quiet" size="lg">See how it works</ButtonLink>
        </div>
        <p className="mt-4 text-sm text-zinc-400">Free · Open source · No account · No app telemetry</p>
        <p className="mx-auto mt-3 max-w-xl text-sm leading-relaxed text-zinc-400">
          v{DOWNLOADS.mac.version} · macOS 13+ · Apple Silicon &amp; Intel. Ad-hoc signed; macOS may need one-time approval.{" "}
          <a href="#install" className="text-zinc-200 underline underline-offset-4">Install help</a>
          {" · "}<a href={REPO} className="text-zinc-200 underline underline-offset-4">Read the source</a>
        </p>
      </div>
      <Demo />
      <details className="mx-auto mb-12 max-w-5xl px-6">
        <summary className="cursor-pointer py-4 text-sm text-zinc-400">See the Coremium panel</summary>
        <Image src="/coremium-panel.png" alt="Coremium's notch panel with automatic modes, per-app choices, and activity details."
          width={1552} height={876} className="mt-4 w-full rounded-2xl border border-line" />
      </details>
    </section>
  );
}
