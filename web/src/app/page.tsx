import { Choices } from "@/components/choices";
import { Facts } from "@/components/facts";
import { Faq } from "@/components/faq";
import { Footer } from "@/components/footer";
import { Hero } from "@/components/hero";
import { Install } from "@/components/install";
import { Nav } from "@/components/nav";
import { Scheduler } from "@/components/scheduler";
import { Telemetry } from "@/components/telemetry";
import { Wordmark } from "@/components/wordmark";

export default function Page() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Scheduler />
        <Choices />
        <Telemetry />
        <Facts />
        <Install />
        <Faq />
        <Wordmark />
      </main>
      <Footer />
    </>
  );
}
