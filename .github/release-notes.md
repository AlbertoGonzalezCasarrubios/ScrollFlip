## Install

1. Download **ScrollFlip.zip**, unzip it and move **ScrollFlip.app** to `/Applications`.
2. Open it. macOS will say it cannot verify the developer, because the app is not notarized by Apple.
   Go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
3. Grant **Accessibility** permission when asked. ScrollFlip starts working immediately.

Universal binary (Apple Silicon + Intel), macOS 13 or later.

Prefer to build it yourself? See the [README](https://github.com/AlbertoGonzalezCasarrubios/ScrollFlip#build-from-source).

**Updating from a previous version:** quit the old one, replace the app, then run
`tccutil reset Accessibility dev.local.ScrollFlip` and grant the permission again.
