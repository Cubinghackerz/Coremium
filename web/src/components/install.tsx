"use client";
import { Check, Copy, Download } from "lucide-react";
import { useState } from "react";
import { ButtonLink } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { INSTALL_CMD, RELEASE } from "@/lib/utils";

function CopyLine({ text }: { text: string }) {
  const [done, setDone] = useState(false);
  return (
    <div className="flex items-center gap-3 rounded-2xl bg-white/[0.04] py-3 pl-5 pr-3 ring-1 ring-inset ring-white/10">
      <code className="min-w-0 flex-1 overflow-x-auto whitespace-nowrap font-mono text-[13.5px] text-zinc-200 [scrollbar-width:none]">{text}</code>
      <button
        type="button"
        onClick={async () => {
          try {
            await navigator.clipboard.writeText(text);
            setDone(true);
            setTimeout(() => setDone(false), 1600);
          } catch {}
        }}
        className="inline-flex h-9 shrink-0 items-center gap-2 rounded-full bg-white/10 px-4 text-sm font-medium text-white transition-colors hover:bg-white/20"
      >
        {done ? <Check className="size-4" aria-hidden /> : <Copy className="size-4" aria-hidden />}
        {done ? "Copied" : "Copy"}
      </button>
    </div>
  );
}

export function Install() {
  return (
    <section id="install" className="mx-auto max-w-4xl px-6 py-24 text-center md:py-32">
      <h2 className="text-balance text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1.02] tracking-[-0.035em]">
        <span className="text-zinc-500">Install in a minute.</span> <span className="text-white">Hover the notch.</span>
      </h2>
      <Tabs defaultValue="dmg" className="mt-12 text-left">
        <div className="flex justify-center">
          <TabsList>
            <TabsTrigger value="dmg">Disk image</TabsTrigger>
            <TabsTrigger value="terminal">Terminal</TabsTrigger>
          </TabsList>
        </div>
        <TabsContent value="dmg" className="mt-10 grid gap-8 md:grid-cols-[auto_1fr] md:items-center">
          <ButtonLink href={RELEASE} size="lg" className="justify-self-start">
            <Download className="size-[18px]" aria-hidden /> Download for macOS
          </ButtonLink>
          <ol className="list-decimal space-y-2 pl-5 text-[16px] leading-relaxed text-zinc-400 marker:text-zinc-600">
            <li>Open the disk image and drag Coremium onto Applications.</li>
            <li>Open it. macOS asks once, because Coremium is signed without a paid Apple developer account: System Settings, Privacy &amp; Security, Open Anyway.</li>
            <li>Follow the short tour, then hover the notch.</li>
          </ol>
        </TabsContent>
        <TabsContent value="terminal" className="mt-10 space-y-4">
          <p className="text-[16px] text-zinc-400">Downloads the latest release, checks its checksum and installs it. macOS shows no warning.</p>
          <CopyLine text={INSTALL_CMD} />
          <p className="pt-2 text-[15px] text-zinc-500">If something stays slow, this puts every app back:</p>
          <CopyLine text="/Applications/Coremium.app/Contents/MacOS/Coremium --restore-all" />
        </TabsContent>
      </Tabs>
    </section>
  );
}
