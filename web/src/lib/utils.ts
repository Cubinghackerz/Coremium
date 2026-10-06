import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";
import downloads from "../../../docs/downloads.json";

export const DOWNLOADS = downloads;

export const cn = (...inputs: ClassValue[]) => twMerge(clsx(inputs));

export const REPO = "https://github.com/Cubinghackerz/Coremium";
export const RELEASE = `${REPO}/releases/latest`;
export const INSTALL_CMD =
  "curl -fsSL https://raw.githubusercontent.com/Cubinghackerz/Coremium/master/scripts/install.sh | bash";
export const INSTALL_CMD_WINDOWS =
  "irm https://raw.githubusercontent.com/Cubinghackerz/Coremium/master/scripts/install.ps1 | iex";
export const WINDOWS_RELEASES = `${REPO}/releases?q=windows&expanded=true`;
