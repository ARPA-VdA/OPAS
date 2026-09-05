Place the font .woff2 files here for embedding in the Electron build.

Recommended files and names (put these exact names into this folder):

- plus-jakarta-sans-300.woff2
- plus-jakarta-sans-400.woff2
- plus-jakarta-sans-600.woff2
- plus-jakarta-sans-700.woff2

- jetbrains-mono-300.woff2
- jetbrains-mono-400.woff2
- jetbrains-mono-600.woff2
- jetbrains-mono-700.woff2

- source-serif-4-400.woff2
- source-serif-4-700.woff2

Where to get them:
- Google Fonts (https://fonts.google.com) — select the families and download the woff2 files.
- Or use a CLI to download (example using wget or curl):

  # Example (run in WSL or any Unix shell):
  mkdir -p public/fonts && cd public/fonts
  wget "https://fonts.gstatic.com/s/plusjakartasans/vxx/...../plus-jakarta-sans-400.woff2" -O plus-jakarta-sans-400.woff2

Notes:
- Electron builds will serve files from the `public/` folder; referencing `/fonts/...` in CSS will work.
- After placing files, rebuild the app (`npm run build`).
- If you want me to download and add the files automatically, I can attempt it, but I will need the exact source URLs or permission to fetch from Google Fonts.
