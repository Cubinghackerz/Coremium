# Coremium website

Next.js (App Router), Tailwind CSS v4, Motion, Radix (accordion, tabs), lucide icons.

```bash
cd web
npm install
npm run dev      # http://localhost:3000
npm run build    # production build
```

Both this site and the GitHub Pages site read [`../docs/downloads.json`](../docs/downloads.json). Update it only after
the release's DMG/ZIP and checksum assets have been published and verified. Local builds and unreleased features must
not be advertised as available in the download. The Next.js workspace root includes the repository so both sites
can share this metadata. Vercel must include files outside `web` when building.

The main CTA is a direct DMG download; Terminal install is optional. The interactive demo is explicitly an
illustration, never a speed benchmark. Preserve keyboard operation, reduced-motion support and visible copy-failure
feedback when editing it.

Before publishing, check both sites at 320, 768 and 1440 pixels wide: direct download targets, workload choices,
pause/resume, Mac/Windows tabs, approval steps and keyboard focus. For a consent-based usability check, ask a new
user to explain the benefit, find the DMG, open Coremium and identify what it is doing without coaching. Record where
they hesitate; do not treat simulated activity or automated tests as conversion or performance evidence.

## Deploy to Vercel

1. Import `Cubinghackerz/Coremium` at vercel.com/new.
2. Set **Root Directory** to `web`. Framework preset: Next.js (auto-detected). No environment variables.
3. Deploy. Update `metadataBase` in `src/app/layout.tsx` to your final domain.

CLI alternative: `cd web && npx vercel --prod`.
