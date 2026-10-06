import Image from "next/image";
import { REPO } from "@/lib/utils";

export function Footer() {
  return (
    <footer className="border-t border-line px-6 py-14 text-sm text-zinc-400">
      <div className="mx-auto flex max-w-6xl flex-wrap items-start justify-between gap-8">
        <div className="max-w-sm">
          <div className="flex items-center gap-3 text-base font-semibold text-white">
            <Image src="/logo.png" alt="" width={24} height={24} className="rounded-md" /> Coremium
          </div>
          <p className="mt-3">Give the app you&apos;re using more room to work.</p>
        </div>
        <div className="flex gap-12">
          <ul className="space-y-2">
            <li><a className="transition-colors hover:text-white" href={REPO}>GitHub</a></li>
            <li><a className="transition-colors hover:text-white" href={`${REPO}/releases`}>Releases</a></li>
            <li><a className="transition-colors hover:text-white" href={`${REPO}/issues`}>Report a problem</a></li>
          </ul>
          <ul className="space-y-2">
            <li><a className="transition-colors hover:text-white" href={`${REPO}/blob/master/SECURITY.md`}>Security</a></li>
            <li><a className="transition-colors hover:text-white" href={`${REPO}/blob/master/LICENSE`}>MIT license</a></li>
          </ul>
        </div>
      </div>
      <p className="mx-auto mt-12 max-w-6xl">Not affiliated with Apple. The Apple logo in the app is Apple&apos;s own system symbol, drawn by macOS.</p>
    </footer>
  );
}
