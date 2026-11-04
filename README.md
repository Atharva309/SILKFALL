# Silkfall

Generative silk for an iPad desk display. It weaves glowing, symmetric patterns on its own, with palettes, a vortex, breathing, tilt parallax and a night mode.

This repository holds two versions of the same app:

- **Web app**: the files at the top level (`index.html` and friends). GitHub Pages serves it at `https://YOURNAME.github.io/silkfall/`.
- **iPad app**: the `ios` folder. GitHub builds it in the cloud every time you upload changes and publishes **Silkfall.ipa** on this repository's **latest** release. You install it with AltStore (or SideStore).

## Download link for the iPad app

```
https://github.com/YOURNAME/silkfall/releases/latest/download/Silkfall.ipa
```

## Updating

Change `index.html` (or anything else), upload it, and wait about five minutes. The **Actions** tab shows the build. When it's green, the new `Silkfall.ipa` is on the latest release and the web app is updated too.

## What the iPad app adds over the web app

- Opens straight into full screen, with no browser bars, status bar or home indicator.
- Keeps the screen awake by itself while it's open, following the **Keep screen awake** switch in settings.
- Tilt parallax works without a permission prompt.
- Shortcuts can open it with **Open App**, so it can start automatically when you put the iPad on the charger.
