import { Download } from "lucide-react";
import Image from "next/image";
import { ButtonLink } from "@/components/ui/button";
import { DOWNLOADS, REPO } from "@/lib/utils";

export function Nav() {
  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-white/[0.06] bg-black/60 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
        <a href="#top" className="flex items-center gap-3 text-[17px] font-semibold tracking-tight">
          <Image src="/logo.png" alt="" width={28} height={28} className="rounded-[7px]" />
          Coremium
        </a>
        <nav aria-label="Main" className="hidden items-center gap-8 text-[15px] text-zinc-400 md:flex">
          <a className="transition-colors hover:text-white" href="#how">How it works</a>
          <a className="transition-colors hover:text-white" href="#facts">Facts</a>
          <a className="transition-colors hover:text-white" href="#install">Install</a>
          <a className="transition-colors hover:text-white" href="#faq">FAQ</a>
          <a className="transition-colors hover:text-white" href={REPO}>GitHub</a>
        </nav>
        <ButtonLink href={DOWNLOADS.mac.download} size="sm" variant="ghost">
          <Download className="size-4" aria-hidden /> Download
        </ButtonLink>
      </div>
    </header>
  );
}
