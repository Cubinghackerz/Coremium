# Coremium website

Next.js (App Router), Tailwind CSS v4, Motion, Radix (accordion, tabs), lucide icons.

```bash
cd web
npm install
npm run dev      # http://localhost:3000
npm run build    # production build
```

## Deploy to Vercel
1. Import `Cubinghackerz/Coremium` at vercel.com/new.
2. Set **Root Directory** to `web`. Framework preset: Next.js (auto-detected). No environment variables.
3. Deploy. Update `metadataBase` in `src/app/layout.tsx` to your final domain.

CLI alternative: `cd web && npx vercel --prod`.
