# ScrollFlip

Reverse the **mouse** scroll wheel on macOS without touching the **trackpad**.

macOS has a single "Natural scrolling" switch, and it applies to both the trackpad and the mouse. If you want natural scrolling on the trackpad and classic, Windows-style scrolling on the mouse wheel, ScrollFlip does exactly that, and nothing else.

- Lives in the menu bar, with no Dock icon.
- Adjustable mouse-wheel speed. It defaults to the system speed.
- Built-in "Try it" tab that shows live what happens to each scroll event.
- English and Spanish UI.
- Only listens to scroll-wheel events. It never sees clicks, keystrokes or pointer movement.
- Sandboxed, with **no network entitlement**: it cannot connect to the internet.
- Never stores or logs events.
- About 800 lines of Swift, with no third-party dependencies.

## Requirements

- macOS 13 Ventura or later.
- An Apple Silicon Mac.
- Xcode or just the Command Line Tools (`xcode-select --install`).

## Install

```bash
git clone <repo-url>
cd ScrollFlip
scripts/create-signing-cert.sh   # once: creates a local signing certificate
./build.sh install               # builds, copies to /Applications and launches
```

On first launch macOS asks for **Accessibility** permission (System Settings → Privacy & Security → Accessibility). The permission is required to modify scroll events. As soon as you grant it, ScrollFlip starts working. You don't need to relaunch it.

### Why the signing certificate?

macOS ties the Accessibility permission to the app's code signature. With ad-hoc signing, every rebuild has a different signature, so the permission silently stops applying. The toggle still shows "on", but the app gets nothing.

`create-signing-cert.sh` creates a self-signed certificate in your login keychain. `build.sh` then uses it automatically, so the permission survives rebuilds. The certificate is only used locally, and you can delete it from Keychain Access at any time.

## Usage

Click the mouse icon in the menu bar:

| Item | What it does |
|---|---|
| Settings & demo… | Opens the settings window (General · Try it · Language). |
| Enabled | Pauses or resumes ScrollFlip. |
| Reverse vertical / horizontal | Chooses which axes are reversed for the mouse. |
| Open at login | Starts ScrollFlip automatically when you log in. |

The settings window has three tabs:

- **General**: on/off, reversed axes, wheel speed (0.5× to 4×, with a *Reset* button back to the default 1×) and launch at login.
- **Try it**: scroll with the mouse and with the trackpad to see the original event, the event apps receive, and whether it was reversed.
- **Language**: system default, English or Spanish.

Set "Natural scrolling" in System Settings to whatever you like for the trackpad. ScrollFlip only fixes the mouse.

> If you run another app that does the same thing (Scroll Reverser, Mos, LinearMouse, Mouse Glide…), quit it. If both reverse the wheel, they cancel each other out.

## Troubleshooting

**It asks for Accessibility and nothing happens.** The permission is probably attached to an old build. Remove the old entries and relaunch:

```bash
tccutil reset Accessibility dev.local.ScrollFlip
./build.sh install
```

Then grant the permission again. If `build.sh` printed "signing ad-hoc", run `scripts/create-signing-cert.sh` first.

## Known limitations

- **Free-spinning "smooth" wheels** (some Logitech MX mice) can send continuous events, like a trackpad. ScrollFlip leaves them unchanged.
- **The Magic Mouse is treated as a trackpad**, because it also sends continuous events. This is usually what you want.
- **Slower speeds (below 1×)** are fully smooth in apps that use pixel deltas, which covers most modern apps. Apps that only read whole lines still move at least one line per notch.

## Privacy

You can check that the app has no network access yourself:

```bash
codesign -d --entitlements - /Applications/ScrollFlip.app
```

The only entitlement listed should be `com.apple.security.app-sandbox`. Without `com.apple.security.network.client`, the system blocks every outgoing connection.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the technical details.

## Uninstall

1. Menu → Quit ScrollFlip.
2. Delete `/Applications/ScrollFlip.app`.
3. Run `tccutil reset Accessibility dev.local.ScrollFlip`.
4. Optionally, delete the "ScrollFlip Local Signing" certificate in Keychain Access.

## License

[MIT](LICENSE) © 2026 Alberto González-Casarrubios
