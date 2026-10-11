"use client";
import { Copy01Icon, Tick02Icon } from "@hugeicons/core-free-icons";
import { Icon } from "@/components/icon";
import { useInView, useReducedMotion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { cn, DOWNLOADS, INSTALL_CMD, INSTALL_CMD_WINDOWS, REPO } from "@/lib/utils";

function useCopy(text: string) {
  const [state, setState] = useState<"idle" | "copied" | "failed">("idle");
  const timeout = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => () => { if (timeout.current) clearTimeout(timeout.current); }, []);
  async function copy() {
    if (timeout.current) clearTimeout(timeout.current);
    try { await navigator.clipboard.writeText(text); setState("copied"); }
    catch { setState("failed"); }
    timeout.current = setTimeout(() => setState("idle"), 2500);
  }
  return { state, copy };
}

function CopyButton({ state, onCopy, label, className }: { state: "idle" | "copied" | "failed"; onCopy: () => void; label: string; className?: string }) {
  return (
    <button type="button" aria-label={`Copy ${label}`} onClick={onCopy}
      className={cn("inline-flex min-h-10 shrink-0 items-center gap-2 rounded-full bg-white px-4 text-sm font-semibold text-black transition-colors hover:bg-zinc-200", className)}>
      <Icon icon={state === "copied" ? Tick02Icon : Copy01Icon} className="size-4" strokeWidth={2} />
      {state === "copied" ? "Copied" : "Copy"}
    </button>
  );
}

function CopyStatus({ state }: { state: "idle" | "copied" | "failed" }) {
  return (
    <p role="status" className="sr-only">
      {state === "failed" ? "Couldn't copy. Select the command and copy it manually." : state === "copied" ? "Command copied." : ""}
    </p>
  );
}

export function CopyLine({ text, label }: { text: string; label: string }) {
  const { state, copy } = useCopy(text);
  return (
    <div>
      <div className="flex items-center gap-3 rounded-2xl bg-black/55 py-2 pl-4 pr-2 ring-1 ring-inset ring-white/15 backdrop-blur-md">
        <code aria-label={label} className="min-w-0 flex-1 break-all text-left font-mono text-[12.5px] leading-relaxed text-zinc-100 sm:text-[13.5px]">
          <span className="select-none text-zinc-500">$ </span>{text}
        </code>
        <CopyButton state={state} onCopy={copy} label={label} />
      </div>
      {state === "failed" ? <p className="mt-2 text-sm text-zinc-400">Couldn&apos;t copy. Select the command and copy it manually.</p> : null}
      <CopyStatus state={state} />
    </div>
  );
}

/* The output lines are the installers' own messages, in order. */
const output = {
  mac: ["Finding the latest release…", "Checksum OK.", "Coremium is installed. Hover the notch (or click the chip icon in the menu bar) to open it."],
  windows: ["Finding the latest Windows release...", "Checksum OK.", `Coremium windows-v${DOWNLOADS.windows.version} is installed. It is in the Start menu and the system tray.`],
};

function Terminal({ os }: { os: "mac" | "windows" }) {
  const mac = os === "mac";
  const command = mac ? INSTALL_CMD : INSTALL_CMD_WINDOWS;
  const lines = output[os];
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { once: true, amount: 0.5 });
  const reduce = useReducedMotion();
  const { state, copy } = useCopy(command);
  const [typed, setTyped] = useState(0);
  const [shown, setShown] = useState(0);

  useEffect(() => {
    if (!inView) return undefined;
    if (reduce) {
      setTyped(command.length);
      setShown(lines.length);
      return undefined;
    }
    let i = 0;
    const typer = window.setInterval(() => {
      i += 2;
      setTyped(Math.min(i, command.length));
      if (i >= command.length) window.clearInterval(typer);
    }, 16);
    const delays = [1.5, 2.9, 3.8].map((s, n) => window.setTimeout(() => setShown(n + 1), s * 1000));
    return () => {
      window.clearInterval(typer);
      delays.forEach(window.clearTimeout);
    };
  }, [inView, reduce, command.length, lines.length]);

  const prompt = mac ? "~ %" : "PS C:\\>";
  const done = shown === lines.length;

  return (
    <div ref={ref} className="overflow-hidden rounded-[20px] bg-[#0c0c0f] text-left ring-1 ring-inset ring-white/12 shadow-[0_40px_90px_-40px_rgba(0,0,0,0.9)]">
      <div className="flex items-center gap-3 border-b border-white/[0.07] px-4 py-2.5">
        <span className="flex gap-1.5" aria-hidden>
          <span className="size-3 rounded-full bg-[#ff5f57]/85" />
          <span className="size-3 rounded-full bg-[#febc2e]/85" />
          <span className="size-3 rounded-full bg-[#28c840]/85" />
        </span>
        <span className="flex-1 text-center text-[12.5px] font-medium text-zinc-500">{mac ? "Terminal — zsh" : "Windows PowerShell"}</span>
        <CopyButton state={state} onCopy={copy} label={mac ? "macOS install command" : "Windows install command"} className="min-h-8 px-3 text-[13px]" />
      </div>
      <div className="min-h-[220px] p-5 font-mono text-[13px] leading-[1.75] md:p-6 md:text-[13.5px]">
        <p className="break-all text-zinc-100">
          <span className="select-none text-mint">{prompt} </span>
          <span className="sr-only">{command}</span>
          <span aria-hidden>{command.slice(0, typed)}</span>
          {typed < command.length ? <span className="caret ml-px inline-block h-[1.1em] w-[0.55em] translate-y-[3px] bg-zinc-300" aria-hidden /> : null}
        </p>
        <div aria-hidden>
          {lines.slice(0, shown).map((line, i) => (
            <p key={line} className={cn("text-pretty", i === lines.length - 1 ? "text-white" : "text-zinc-400", line === "Checksum OK." && "text-mint")}>{line}</p>
          ))}
          {done ? (
            <p className="text-zinc-100">
              <span className="text-mint">{prompt} </span>
              <span className="caret inline-block h-[1.1em] w-[0.55em] translate-y-[3px] bg-zinc-300" />
            </p>
          ) : null}
        </div>
      </div>
      <CopyStatus state={state} />
    </div>
  );
}

function Panel({ os }: { os: "mac" | "windows" }) {
  const mac = os === "mac";
  const release = DOWNLOADS[os];
  return (
    <div className="grid gap-10 text-left lg:grid-cols-[1.35fr_1fr] lg:gap-14">
      <div>
        <Terminal os={os} />
        <p className="mt-4 text-sm text-zinc-500">v{release.version} · {mac ? "macOS 13+, Apple Silicon & Intel" : "Windows 10 & 11, x64 · beta"}</p>
      </div>
      <div>
        {mac ? (
          <>
            <h3 className="text-lg font-semibold text-white">What the installer does</h3>
            <ol className="mt-5 space-y-4">
              {[
                "Finds the latest release on GitHub and downloads its zip.",
                "Checks the zip against the published SHA-256 checksum. If they differ, nothing is installed.",
                "Quits a running Coremium (which restores every app it moved), copies it to Applications and opens it.",
              ].map((step, i) => (
                <li key={step} className="flex gap-4 text-[15px] leading-relaxed text-zinc-300">
                  <span className="grid size-6 shrink-0 place-items-center rounded-full bg-white/[0.08] font-mono text-[12px] text-zinc-300">{i + 1}</span>
                  {step}
                </li>
              ))}
            </ol>
            <p className="mt-6 text-sm leading-relaxed text-zinc-500">
              Files fetched with curl aren&apos;t quarantined, so macOS doesn&apos;t block the first open. Coremium is ad-hoc signed and not notarized; if you
              download the zip yourself, the FAQ has the approval steps.
            </p>
            <h3 className="mt-10 text-base font-semibold text-white">Prefer Homebrew?</h3>
            <div className="mt-3">
              <CopyLine text="brew install --cask cubinghackerz/tap/coremium" label="Homebrew install command" />
            </div>
            <p className="mt-3 text-sm leading-relaxed text-zinc-500">Homebrew can quarantine its download, and then macOS may block the first open. The one-line installer avoids that.</p>
          </>
        ) : (
          <>
            <h3 className="text-lg font-semibold text-white">About the Windows beta</h3>
            <p className="mt-4 text-[15px] leading-relaxed text-zinc-400">
              The Windows build is unsigned and has automated tests, but it still needs hands-on testing on Windows PCs. Report any Windows Security message
              with its exact wording.
            </p>
          </>
        )}
        <p className="mt-8 text-sm text-zinc-400">
          <a href={`${REPO}/blob/master/scripts/install.${mac ? "sh" : "ps1"}`} className="text-zinc-200 underline decoration-white/30 underline-offset-4 hover:decoration-white">Read the installer before you run it</a>
          {" · "}
          <a href={`${REPO}/releases`} className="text-zinc-200 underline decoration-white/30 underline-offset-4 hover:decoration-white">Release notes</a>
        </p>
      </div>
    </div>
  );
}

export function Install() {
  return (
    <section id="install" className="mx-auto max-w-6xl scroll-mt-16 px-5 py-24 md:px-6 md:py-36">
      <div className="flex flex-col gap-6">
        <h2 className="text-balance max-w-4xl text-[clamp(34px,5vw,64px)] font-semibold leading-[1] tracking-[-0.04em]">
          One line. <span className="text-white/45">Then let Automatic take it from there.</span>
        </h2>
        <p className="max-w-md text-[16px] leading-relaxed text-zinc-400">No account, no sign-up, and nothing is sent anywhere except the download.</p>
      </div>
      <Tabs defaultValue="mac" className="mt-12">
        <TabsList><TabsTrigger value="mac">macOS</TabsTrigger><TabsTrigger value="windows">Windows beta</TabsTrigger></TabsList>
        <TabsContent value="mac" className="mt-8"><Panel os="mac" /></TabsContent>
        <TabsContent value="windows" className="mt-8"><Panel os="windows" /></TabsContent>
      </Tabs>
    </section>
  );
}
