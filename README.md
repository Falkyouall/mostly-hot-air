# Mostly Hot Air

See [`BALLON_GDD.md`](BALLON_GDD.md) — the Game Design Document is the main source of truth for vision, mechanics, and development stages.

## Play in the browser

Every push to `main` or `m2-prototype` builds all MVPs and publishes them to the `gh-pages` branch
(`.github/workflows/pages.yml`). With GitHub Pages set to *Deploy from a branch → gh-pages / (root)*,
the landing page lists every prototype at `https://falkyouall.github.io/mostly-hot-air/`.

## How to start locally

`mvp_beta`, `mvp_ceta` and `mvp_delta` are static three.js pages:

```bash
npx serve mvp_beta   # or mvp_ceta, mvp_delta
```

`mvp_epsilon` and `mvp_zeta` are Godot 4.5 projects, see their READMEs:

```bash
godot --path mvp_zeta
```

To build the whole site as it goes online (needs the Godot 4.5.1 web export templates):

```bash
tools/build_site.sh /Applications/Godot.app/Contents/MacOS/Godot
npx serve build/site
```
