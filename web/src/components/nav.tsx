import Image from "next/image";
import { Notch } from "@/components/notch";
import { REPO } from "@/lib/utils";

const link = "rounded-md px-2.5 py-1 transition-colors hover:bg-white/10 hover:text-white";

/* A menu bar: app menus on the left, status items on the right, the notch in between. */
export function Nav() {
  return (
    <header className="fixed inset-x-0 top-0 z-50 h-[var(--bar)] border-b border-white/[0.06] bg-black/40 backdrop-blur-xl backdrop-saturate-150">
      <div className="relative mx-auto flex h-full max-w-[1400px] items-center justify-between px-3 md:px-5">
        <nav aria-label="Main" className="flex items-center gap-1 text-[13.5px] text-zinc-300">
          <a href="#top" className="mr-2 flex items-center gap-2 rounded-md px-1.5 py-1 font-semibold text-white">
            <Image src="/brand/mark-white.png" alt="" width={18} height={19} priority />
            <span className="hidden sm:inline">Coremium</span>
          </a>
          <a className={`${link} hidden xl:inline-block`} href="#screens">Screens</a>
          <a className={`${link} hidden xl:inline-block`} href="#how">How it works</a>
          <a className={`${link} hidden xl:inline-block`} href="#numbers">Numbers</a>
        </nav>

        <Notch />

        <div className="flex items-center gap-1 text-[13.5px] text-zinc-300">
          <a className={`${link} hidden xl:inline-block`} href="#faq">FAQ</a>
          <a className={`${link} hidden md:inline-block`} href={REPO}>GitHub</a>
          <a href="#install" className="ml-1 inline-flex h-7 items-center rounded-full bg-white px-3.5 text-[13px] font-semibold text-black transition-colors hover:bg-zinc-200">
            Install
          </a>
        </div>
      </div>
    </header>
  );
}
