"use client";
import { Check, Copy, Download } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ButtonLink } from "@/components/ui/button";
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
    <div className="text-left">
      <div className="grid gap-8 md:grid-cols-2">
        <div>
          <ButtonLink href={release.download} size="lg" className="w-full sm:w-auto">
            <Download className="size-5" aria-hidden /> {mac ? "Download for Mac — Free" : "Download Windows beta"}
          </ButtonLink>
          <p className="mt-4 text-sm text-zinc-400">v{release.version} · {mac ? "macOS 13+, Apple Silicon & Intel" : "Windows 10 & 11, x64 · Beta"}</p>
          <ol className="mt-6 list-decimal space-y-3 pl-5 text-base leading-relaxed text-zinc-300">
            <li>{mac ? "Open the disk image and drag Coremium to Applications." : "Extract the zip to a folder you want to keep."}</li>
            <li>{mac ? "Open Coremium. If the developer cannot be verified, follow the approval steps beside this." : "Open Coremium.exe. Check the publisher and any Windows Security message before proceeding."}</li>
            <li>{mac ? "Automatic follows your game or work app. Hover the notch or use the menu-bar chip to see activity." : "Automatic follows your game or work app. Use the tray icon to reopen the window."}</li>
          </ol>
          <p className="mt-5 text-sm text-zinc-400"><a href={release.checksums} className="underline underline-offset-4">Published SHA-256 checksums</a>{" · "}<a href={`${REPO}/releases`} className="underline underline-offset-4">Release notes</a></p>
        </div>
        <div className="rounded-xl border border-line bg-white/[0.035] p-6">
          <h3 className="text-lg font-semibold text-white">{mac ? "First-open approval" : "About the Windows beta"}</h3>
          {mac ? <>
            <p className="mt-3 text-sm leading-relaxed text-zinc-400">Coremium is ad-hoc signed and not notarized. For an unidentified-developer warning, after trying to open it:</p>
            <ol className="mt-4 list-decimal space-y-3 pl-5 text-sm leading-relaxed text-zinc-300">
              <li>Open <strong>System Settings → Privacy &amp; Security</strong>.</li>
              <li>Find the Coremium message and choose <strong>Open Anyway</strong>.</li>
              <li>Confirm <strong>Open</strong>. Later launches use this exception.</li>
            </ol>
            <p className="mt-4 text-sm leading-relaxed text-zinc-400">If it says “will damage your computer” or “is damaged,” stop and report the exact message instead of using these steps.</p>
            <a href="https://support.apple.com/en-au/102445" className="mt-4 inline-block text-sm text-zinc-200 underline underline-offset-4">Apple&apos;s guide to opening downloaded apps</a>
          </> : <>
            <p className="mt-3 text-sm leading-relaxed text-zinc-400">Windows builds are currently unsigned. An unrecognized-app message concerns reputation; a malware or potentially unwanted app detection needs investigation. Please report its exact wording.</p>
            <p className="mt-4 text-sm leading-relaxed text-zinc-400">The beta has automated tests, but still needs hands-on testing on Windows PCs.</p>
          </>}
        </div>
      </div>
      <details className="mt-8 border-t border-line pt-5">
        <summary className="cursor-pointer py-2 text-sm text-zinc-300">Other installation methods: {mac ? "Terminal" : "PowerShell"}</summary>
        <p className="my-4 text-sm leading-relaxed text-zinc-400">The optional script downloads a release, verifies its published checksum, installs it, and opens the app. Read the script on GitHub before running it.</p>
        <CopyLine text={mac ? INSTALL_CMD : INSTALL_CMD_WINDOWS} label={mac ? "macOS install command" : "Windows install command"} />
        <a href={`${REPO}/blob/master/scripts/install.${mac ? "sh" : "ps1"}`} className="text-sm text-zinc-300 underline underline-offset-4">Read the installer source</a>
      </details>
    </div>
  );
}

export function Install() {
  return (
    <section id="install" className="mx-auto max-w-5xl scroll-mt-20 px-6 py-20 text-center md:py-24">
      <h2 className="text-balance text-[clamp(32px,4.6vw,56px)] font-semibold leading-[1.02] tracking-[-0.035em]">Download. Open. <span className="text-zinc-400">Let Automatic take it from there.</span></h2>
      <Tabs defaultValue="mac" className="mt-10">
        <div className="flex justify-center"><TabsList><TabsTrigger value="mac">macOS</TabsTrigger><TabsTrigger value="windows">Windows beta</TabsTrigger></TabsList></div>
        <TabsContent value="mac" className="mt-8"><Panel os="mac" /></TabsContent>
        <TabsContent value="windows" className="mt-8"><Panel os="windows" /></TabsContent>
      </Tabs>
    </section>
  );
}
