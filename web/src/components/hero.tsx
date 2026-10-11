import { CopyLine } from "@/components/install";
import { NotchGallery } from "@/components/notch-gallery";
import { DOWNLOADS, INSTALL_CMD, REPO } from "@/lib/utils";

export function Hero() {
  return (
    <section id="top" className="relative overflow-hidden pt-28 md:pt-36">
      <div className="mx-auto max-w-6xl px-6 text-center">
        <h1 className="text-balance mx-auto max-w-4xl text-[clamp(40px,6.5vw,80px)] font-semibold leading-[1.04] tracking-[-0.04em]">
          Give the app you&apos;re using <span className="text-zinc-400">more room to work.</span>
        </h1>
        <p className="mx-auto mt-6 max-w-xl text-lg leading-relaxed text-zinc-400">
          Coremium lowers background-app priority while you play, create, code, or run local AI. Your other apps stay open.
        </p>
        <div className="mx-auto mt-8 max-w-2xl text-left">
          <CopyLine text={INSTALL_CMD} label="macOS install command" />
        </div>
        <p className="mt-4 text-sm text-zinc-400">
          Free · Open source · No account · v{DOWNLOADS.mac.version} · macOS 13+ · Apple Silicon &amp; Intel
        </p>
        <p className="mt-2 text-sm text-zinc-400">
          <a href="#install" className="text-zinc-200 underline underline-offset-4">More install options</a>
          {" · "}
          <a href={REPO} className="text-zinc-200 underline underline-offset-4">Read the source</a>
        </p>
      </div>
      <NotchGallery />
    </section>
  );
}
