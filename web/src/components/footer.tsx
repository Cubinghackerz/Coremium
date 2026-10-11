import Image from "next/image";
import { REPO } from "@/lib/utils";

export function Footer() {
  return (
    <footer className="border-t border-line px-5 py-14 text-sm text-zinc-400 md:px-6">
      <div className="mx-auto flex max-w-6xl flex-wrap items-start justify-between gap-10">
        <div className="max-w-sm">
          <Image src="/brand/lockup-white.png" alt="Coremium" width={1043} height={765} className="h-14 w-auto" />
          <p className="mt-5">Give the app you&apos;re using more room to work.</p>
        </div>
        <div className="flex gap-14">
          <ul className="space-y-2.5">
            <li><a className="transition-colors hover:text-white" href={REPO}>GitHub</a></li>
            <li><a className="transition-colors hover:text-white" href={`${REPO}/releases`}>Releases</a></li>
            <li><a className="transition-colors hover:text-white" href={`${REPO}/issues`}>Report a problem</a></li>
          </ul>
          <ul className="space-y-2.5">
            <li><a className="transition-colors hover:text-white" href={`${REPO}/blob/master/SECURITY.md`}>Security</a></li>
            <li><a className="transition-colors hover:text-white" href={`${REPO}/blob/master/LICENSE`}>MIT license</a></li>
          </ul>
        </div>
      </div>
      <p className="mx-auto mt-12 max-w-6xl text-zinc-500">Not affiliated with Apple. The Apple logo in the app is Apple&apos;s own system symbol, drawn by macOS.</p>
    </footer>
  );
}
