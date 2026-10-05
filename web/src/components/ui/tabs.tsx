"use client";
import * as TabsPrimitive from "@radix-ui/react-tabs";
import * as React from "react";
import { cn } from "@/lib/utils";

export const Tabs = TabsPrimitive.Root;

export const TabsList = ({ className, ...props }: React.ComponentProps<typeof TabsPrimitive.List>) => (
  <TabsPrimitive.List className={cn("inline-flex rounded-full bg-white/[0.06] p-1 ring-1 ring-inset ring-white/10", className)} {...props} />
);

export const TabsTrigger = ({ className, ...props }: React.ComponentProps<typeof TabsPrimitive.Trigger>) => (
  <TabsPrimitive.Trigger
    className={cn(
      "rounded-full px-5 py-2 text-sm font-medium text-zinc-400 transition-colors data-[state=active]:bg-white data-[state=active]:text-black",
      className,
    )}
    {...props}
  />
);

export const TabsContent = TabsPrimitive.Content;
