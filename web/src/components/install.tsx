"use client";
import { Check, Copy } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { DOWNLOADS, INSTALL_CMD, INSTALL_CMD_WINDOWS, REPO } from "@/lib/utils";

export function CopyLine({ text, label }: { text: string; label: string }) {
  const [state, setState] = useState<"idle" | "copied" | "failed">("idle");
  const timeout = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => () => { if (timeout.current) clearTimeout(timeout.current); }, []);
  return (
    <div>
      <div className="flex items-center gap-3 rounded-xl bg-white/[0.05] py-3 pl-4 pr-3 ring-1 ring-inset ring-white/12">
        <code aria-label={label} className="min-w-0 flex-1 overflow-x-auto whitespace-nowrap font-mono text-sm text-zinc-100">{text}</code>
        <button type="button" aria-label={`Copy ${label}`} onClick={async () => {
          if (timeout.current) clearTimeout(timeout.current);
          try { await navigator.clipboard.writeText(text); setState("copied"); }
          catch { setState("failed"); }
          timeout.current = setTimeout(() => setState("idle"), 2500);
        }} className="inline-flex min-h-11 shrink-0 items-center gap-2 rounded-full bg-white px-4 text-sm font-medium text-black hover:bg-zinc-200">
          {state === "copied" ? <Check className="size-4" aria-hidden /> : <Copy className="size-4" aria-hidden />}
          {state === "copied" ? "Copied" : "Copy"}
        </button>
      </div>
      <p role="status" className="mt-2 text-sm text-zinc-400">{state === "failed" ? "Couldn't copy. Select the command and copy it manually." : state === "copied" ? "Command copied." : ""}</p>
    </div>
  );
}

function Panel({ os }: { os: "mac" | "windows" }) {
  const mac = os === "mac";
  const release = DOWNLOADS[os];
  return (
    <div className="grid gap-8 text-left md:grid-cols-2">
      <div>
        <p className="text-sm text-zinc-400">v{release.version} · {mac ? "macOS 13+, Apple Silicon & Intel" : "Windows 10 & 11, x64 · beta"}</p>
        <div className="mt-4">
          <CopyLine text={mac ? INSTALL_CMD : INSTALL_CMD_WINDOWS} label={mac ? "macOS install command" : "Windows install command"} />
        </div>
        {mac ? (
          <>
            <h3 className="mt-8 text-base font-semibold text-white">Homebrew</h3>
            <div className="mt-3">
              <CopyLine text="brew install --cask cubinghackerz/tap/coremium" label="Homebrew install command" />
            </div>
            <p className="mt-3 text-sm leading-relaxed text-zinc-400">
              Homebrew can mark its download as quarantined, and then macOS may block the first open. If that happens, use the one-line installer.
            </p>
          </>
        ) : null}
        <p className="mt-6 text-sm text-zinc-400">
          <a href={`${REPO}/blob/master/scripts/install.${mac ? "sh" : "ps1"}`} className="text-zinc-200 underline underline-offset-4">Read the installer before you run it</a>
          {" · "}
          <a href={`${REPO}/releases`} className="text-zinc-200 underline underline-offset-4">Release notes</a>
        </p>
      </div>
      <div className="rounded-xl border border-line bg-white/[0.035] p-6">
        {mac ? (
          <>
            <h3 className="text-lg font-semibold text-white">What the installer does</h3>
            <ol className="mt-4 list-decimal space-y-3 pl-5 text-sm leading-relaxed text-zinc-300">
              <li>Finds the latest release on GitHub and downloads its zip.</li>
              <li>Checks the zip against the published SHA-256 checksum. If they differ, nothing is installed.</li>
              <li>Quits a running Coremium (quitting restores every app it moved), copies it to Applications, and opens it.</li>
            </ol>
            <p className="mt-5 text-sm leading-relaxed text-zinc-400">
              Files fetched with curl aren&apos;t quarantined, so macOS doesn&apos;t block the first open. Coremium is ad-hoc signed and not notarized. If you download the zip from the releases page yourself, see the FAQ for the approval steps.
            </p>
          </>
        ) : (
          <>
            <h3 className="text-lg font-semibold text-white">About the Windows beta</h3>
            <p className="mt-4 text-sm leading-relaxed text-zinc-400">
              The Windows build is unsigned and has automated tests, but it still needs hands-on testing on Windows PCs. Report any Windows Security message with its exact wording.
            </p>
          </>
        )}
      </div>
    </div>
  );
}

export function Install() {
  return (
    <section id="install" className="mx-auto max-w-5xl scroll-mt-20 px-6 py-20 text-center md:py-24">
      <h2 className="text-balance text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1.02] tracking-[-0.035em]">
        One line. <span className="text-zinc-400">Then let Automatic take it from there.</span>
      </h2>
      <p className="mx-auto mt-5 max-w-xl text-base leading-relaxed text-zinc-400">
        The installer runs on your Mac. No account, no sign-up, and nothing is sent anywhere except the download.
      </p>
      <Tabs defaultValue="mac" className="mt-10">
        <div className="flex justify-center"><TabsList><TabsTrigger value="mac">macOS</TabsTrigger><TabsTrigger value="windows">Windows beta</TabsTrigger></TabsList></div>
        <TabsContent value="mac" className="mt-8"><Panel os="mac" /></TabsContent>
        <TabsContent value="windows" className="mt-8"><Panel os="windows" /></TabsContent>
      </Tabs>
    </section>
  );
}
