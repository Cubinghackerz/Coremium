import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export const cn = (...inputs: ClassValue[]) => twMerge(clsx(inputs));

export const REPO = "https://github.com/Cubinghackerz/Coremium";
export const RELEASE = `${REPO}/releases/latest`;
export const INSTALL_CMD =
  "curl -fsSL https://raw.githubusercontent.com/Cubinghackerz/Coremium/master/scripts/install.sh | bash";
