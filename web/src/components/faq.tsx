import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";

const items: [string, string][] = [
  ["Does it close or freeze my apps?", "No. Coremium never quits anything on its own, and it doesn't suspend or freeze apps. It lowers the scheduling priority of background apps so macOS runs them on the efficiency cores, and puts them back when you're done, when you pause, or when you quit Coremium."],
  ["Will it make my game run faster?", "It can't promise that, so it doesn't. When your Mac has more busy work than cores, moving background apps aside can reduce competition for the CPU in front of you. When your Mac isn't overloaded there is little to move. Coremium shows what it measures: how long a boost ran and how many processes it moved."],
  ["Why does macOS warn me when I open it?", "The one-line installer doesn't trigger it: files it downloads aren't quarantined. Coremium is ad-hoc signed and not notarized, so if you download the zip from the releases page yourself, macOS may block the first open. Then try opening it, and use System Settings, Privacy & Security, Open Anyway. A warning that it will damage your computer or is damaged is different: stop and report the exact message."],
  ["What does Yield mean?", "Yield is a choice for one app: step aside to the efficiency cores while something else is boosted. Eco keeps an app on the efficiency cores all the time unless you're using it. Boost protects an app, and Normal leaves it alone."],
  ["Can it raise my game above normal priority?", "No. macOS has no public way to do that without root. Boost works by protecting the app and moving the others aside."],
  ["Does it work on Intel Macs and older macOS?", "It is built for macOS 13 and later, Apple Silicon and Intel. Intel Macs have no efficiency cores, so moved apps simply get lower priority. So far it has only been tested on macOS 27 with an M3 Pro, and reports are welcome."],
  ["What data does it collect?", "None. There is no account and no telemetry. The Mac app's only network request is a once-a-day check for a new version on GitHub, which you can turn off in Settings. Its history of how long boosts ran stays on your Mac in ~/Library/Application Support/Coremium."],
  ["What if something stays slow?", "Quit Coremium from its menu-bar icon, or run /Applications/Coremium.app/Contents/MacOS/Coremium --restore-all in Terminal. Both put every app back."],
];

export function Faq() {
  return (
    <section id="faq" className="mx-auto grid max-w-6xl scroll-mt-16 gap-10 px-5 py-24 md:px-6 md:py-36 lg:grid-cols-[0.9fr_1.4fr] lg:gap-20">
      <h2 className="text-balance text-[clamp(34px,5vw,64px)] font-semibold leading-[1] tracking-[-0.04em] lg:sticky lg:top-28 lg:self-start">
        Questions, <span className="text-white/45">answered plainly.</span>
      </h2>
      <Accordion type="single" collapsible className="border-t border-line">
        {items.map(([q, a], i) => (
          <AccordionItem key={q} value={`q${i}`}>
            <AccordionTrigger>{q}</AccordionTrigger>
            <AccordionContent>{a}</AccordionContent>
          </AccordionItem>
        ))}
      </Accordion>
    </section>
  );
}
