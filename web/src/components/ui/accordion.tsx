"use client";
import * as AccordionPrimitive from "@radix-ui/react-accordion";
import { Plus } from "lucide-react";
import * as React from "react";
import { cn } from "@/lib/utils";

export const Accordion = AccordionPrimitive.Root;

export const AccordionItem = ({ className, ...props }: React.ComponentProps<typeof AccordionPrimitive.Item>) => (
  <AccordionPrimitive.Item className={cn("border-b border-line", className)} {...props} />
);

export const AccordionTrigger = ({ className, children, ...props }: React.ComponentProps<typeof AccordionPrimitive.Trigger>) => (
  <AccordionPrimitive.Header className="flex">
    <AccordionPrimitive.Trigger
      className={cn("group flex flex-1 items-center justify-between gap-6 py-6 text-left text-lg font-medium text-white", className)}
      {...props}
    >
      {children}
      <Plus className="size-5 shrink-0 text-zinc-500 transition-transform duration-300 group-data-[state=open]:rotate-45" aria-hidden />
    </AccordionPrimitive.Trigger>
  </AccordionPrimitive.Header>
);

export const AccordionContent = ({ className, children, ...props }: React.ComponentProps<typeof AccordionPrimitive.Content>) => (
  <AccordionPrimitive.Content
    className="overflow-hidden text-[16px] leading-relaxed text-zinc-400 data-[state=closed]:animate-[acc-up_.25s_ease-out] data-[state=open]:animate-[acc-down_.3s_ease-out]"
    {...props}
  >
    <div className={cn("max-w-2xl pb-6", className)}>{children}</div>
  </AccordionPrimitive.Content>
);
