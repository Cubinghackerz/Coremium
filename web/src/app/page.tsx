import { Faq } from "@/components/faq";
import { Facts } from "@/components/facts";
import { Features } from "@/components/features";
import { Footer } from "@/components/footer";
import { Hero } from "@/components/hero";
import { Install } from "@/components/install";
import { Modes } from "@/components/modes";
import { Nav } from "@/components/nav";
import { NotchGallery } from "@/components/notch-gallery";

export default function Page() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <NotchGallery />
        <Modes />
        <Features />
        <Facts />
        <Install />
        <Faq />
      </main>
      <Footer />
    </>
  );
}
