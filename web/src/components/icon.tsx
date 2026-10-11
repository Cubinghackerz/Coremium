import { HugeiconsIcon, type IconSvgElement } from "@hugeicons/react";

export type { IconSvgElement };

/* One icon pack for the whole site (Hugeicons, stroke style), one stroke weight. Decorative unless labelled by its control. */
export function Icon({ icon, className, strokeWidth = 1.7 }: { icon: IconSvgElement; className?: string; strokeWidth?: number }) {
  return <HugeiconsIcon icon={icon} className={className} strokeWidth={strokeWidth} color="currentColor" aria-hidden />;
}
