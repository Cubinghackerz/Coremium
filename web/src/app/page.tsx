import { Demo } from "@/components/demo";
import { Faq } from "@/components/faq";
import { Facts } from "@/components/facts";
import { Features } from "@/components/features";
import { Footer } from "@/components/footer";
import { Hero } from "@/components/hero";
import { Install } from "@/components/install";
import { Modes } from "@/components/modes";
import { Nav } from "@/components/nav";
import { Showcase } from "@/components/showcase";
import { Steps } from "@/components/steps";
import { Wordmark } from "@/components/wordmark";

export default function Page() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Steps />
        <Showcase />
        <Demo />
        <Modes />
        <Features />
        <Facts />
        <Install />
        <Faq />
        <Wordmark />
      </main>
      <Footer />
    </>
  );
}
