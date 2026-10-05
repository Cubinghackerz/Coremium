"use client";
import { Check, Copy, Download, ShieldCheck } from "lucide-react";
import { useEffect, useState } from "react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { INSTALL_CMD, INSTALL_CMD_WINDOWS, RELEASE, WINDOWS_RELEASES } from "@/lib/utils";

export function CopyLine({ text, label }: { text: string; label: string }) {
  const [done, setDone] = useState(false);
  return (
    <div className="flex items-center gap-3 rounded-2xl bg-white/[0.05] py-3 pl-5 pr-3 ring-1 ring-inset ring-white/12">
      <code aria-label={label} className="min-w-0 flex-1 overflow-x-auto whitespace-nowrap font-mono text-[13.5px] text-zinc-100 [scrollbar-width:none]">{text}</code>
      <button
        type="button"
        onClick={async () => {
          try { await navigator.clipboard.writeText(text); setDone(true); setTimeout(() => setDone(false), 1600); } catch {}
        }}
        className="inline-flex h-9 shrink-0 items-center gap-2 rounded-full bg-white px-4 text-sm font-medium text-black transition-colors hover:bg-zinc-200"
      >
        {done ? <Check className="size-4" aria-hidden /> : <Copy className="size-4" aria-hidden />}
        {done ? "Copied" : "Copy"}
      </button>
    </div>
  );
}

const why = [
  ["Checked before it runs", "The script downloads the latest release and compares its SHA-256 checksum with the one published next to it. If they differ, nothing is installed."],
  ["No security warning to click through", "Files fetched from a terminal aren't flagged as downloads, so macOS Gatekeeper and Windows SmartScreen don't stop the first launch."],
  ["No admin rights, easy to update", "It installs for you only and starts the app. Run the same line again later to update."],
] as const;

function Panel({ os }: { os: "mac" | "windows" }) {
  const mac = os === "mac";
  return (
    <div className="grid grid-cols-[minmax(0,1fr)] gap-10 text-left md:grid-cols-[minmax(0,1.25fr)_minmax(0,1fr)]">
      <div>
        <p className="text-[16px] text-zinc-400">
          {mac ? "Open Terminal (in Applications › Utilities), paste this and press Return:" : "Open PowerShell (Start menu › PowerShell), paste this and press Enter:"}
        </p>
        <div className="mt-4">
          <CopyLine text={mac ? INSTALL_CMD : INSTALL_CMD_WINDOWS} label={mac ? "macOS install command" : "Windows install command"} />
        </div>
        <p className="mt-4 text-[14.5px] text-zinc-500">
          {mac
            ? "Installs Coremium into Applications and opens it. macOS 13 or later, Apple Silicon and Intel."
            : "Installs Coremium for Windows (beta) into your user folder, adds it to the Start menu and starts it. Windows 10 and 11, x64."}
        </p>
        <p className="mt-8 text-[14.5px] text-zinc-500">
          Prefer to download it yourself?{" "}
          <a className="inline-flex items-center gap-1.5 text-zinc-200 underline decoration-zinc-600 underline-offset-4 hover:decoration-white" href={mac ? RELEASE : WINDOWS_RELEASES}>
            <Download className="size-3.5" aria-hidden />
            {mac ? "Disk image" : "Zip (beta)"}
          </a>
          {mac
            ? ". macOS asks once because Coremium is signed without a paid Apple account: System Settings › Privacy & Security › Open Anyway."
            : ". It isn't code-signed yet, so SmartScreen asks once: More info › Run anyway."}
        </p>
        <p className="mt-3 text-[14.5px] text-zinc-500">
          Something stays slow? <code className="break-all font-mono text-[13px] text-zinc-300">{mac ? "/Applications/Coremium.app/Contents/MacOS/Coremium --restore-all" : "Coremium.exe --restore-all"}</code> puts every app back.
        </p>
      </div>
      <div className="rounded-[24px] bg-white/[0.035] p-7 ring-1 ring-inset ring-white/10">
        <p className="flex items-center gap-2 text-[15px] font-semibold text-white">
          <ShieldCheck className="size-[18px] text-perf" aria-hidden /> Why the terminal is the recommended way
        </p>
        <dl className="mt-5 space-y-5">
          {why.map(([t, d]) => (
            <div key={t}>
              <dt className="text-[15px] font-medium text-zinc-100">{t}</dt>
              <dd className="mt-1 text-[14.5px] leading-relaxed text-zinc-400">{d}</dd>
            </div>
          ))}
        </dl>
        <p className="mt-5 text-[13.5px] text-zinc-500">The script is short and readable on GitHub before you run it.</p>
      </div>
    </div>
  );
}

export function Install() {
  const [os, setOs] = useState("mac");
  useEffect(() => { if (/Windows/i.test(navigator.userAgent)) setOs("windows"); }, []);
  return (
    <section id="install" className="mx-auto max-w-5xl px-6 py-24 text-center md:py-32">
      <h2 className="text-balance text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1.02] tracking-[-0.035em]">
        <span className="text-zinc-500">One line to install.</span> <span className="text-white">Done in a minute.</span>
      </h2>
      <Tabs value={os} onValueChange={setOs} className="mt-12">
        <div className="flex justify-center">
          <TabsList>
            <TabsTrigger value="mac">macOS</TabsTrigger>
            <TabsTrigger value="windows">Windows (beta)</TabsTrigger>
          </TabsList>
        </div>
        <TabsContent value="mac" className="mt-10"><Panel os="mac" /></TabsContent>
        <TabsContent value="windows" className="mt-10"><Panel os="windows" /></TabsContent>
      </Tabs>
    </section>
  );
}
