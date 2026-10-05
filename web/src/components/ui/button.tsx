import { cva, type VariantProps } from "class-variance-authority";
import * as React from "react";
import { cn } from "@/lib/utils";

const button = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-full font-medium transition-colors duration-200 disabled:opacity-50",
  {
    variants: {
      variant: {
        solid: "bg-white text-black hover:bg-zinc-200",
        ghost: "bg-white/[0.07] text-white ring-1 ring-inset ring-white/10 hover:bg-white/[0.12]",
        quiet: "text-zinc-400 hover:text-white",
      },
      size: { sm: "h-9 px-4 text-sm", md: "h-11 px-6 text-[15px]", lg: "h-12 px-7 text-base" },
    },
    defaultVariants: { variant: "solid", size: "md" },
  },
);

type Props = React.AnchorHTMLAttributes<HTMLAnchorElement> & VariantProps<typeof button>;

export function ButtonLink({ className, variant, size, ...props }: Props) {
  return <a className={cn(button({ variant, size }), className)} {...props} />;
}

export { button };
