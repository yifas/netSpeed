# NetSpeed — Live Network Speed in the macOS Menu Bar

[简体中文](README.md) | **English**

A small personal-use macOS menu bar app: shows the current **download speed** (and optionally the **upload speed**) in real time. Click the menu to see per-interface details, switch the accounting scope, and change the refresh interval.

- No Dock icon (`LSUIElement=1`) — it lives only in the menu bar
- Data comes from the kernel's per-interface cumulative byte counters via `getifaddrs` / `if_data` (no root, no drivers)
- Pure Swift + AppKit (`NSStatusItem`), zero third-party dependencies

## Screenshot

![NetSpeed in the menu bar](docs/screenshot.png)

The menu bar label is fixed-width: `↓` is the download speed, `↑` is the upload speed, and the unit switches automatically between `K` / `M` / `G`.

---

## 1. Survey of existing GitHub projects

> Note: at the time of writing this machine could not reach GitHub directly (`api.github.com` / `github.com` were blocked, DNS resolved to a poisoned IP `198.20.0.26`).
> The survey was therefore done by locating repositories through the **Bing index (cn.bing.com RSS)** and verifying them by cloning through the **gitclone.com proxy**;
> every repository marked ✅ below was confirmed to exist with `git ls-remote`.

| Project | Description | Verdict |
|---|---|---|
| [yujitach/MenuMeters](https://github.com/yujitach/MenuMeters) ✅(index-verified) | Classic macOS menu bar system monitor (has a network plugin), Objective-C, quite old | Overlaps in features, but not a dedicated speed tool and the UI is dated |
| [exelban/stats](https://github.com/exelban/stats) ✅(index-verified) | Open-source menu bar system monitor (CPU/GPU/memory/network), SwiftUI | Closest in feature set with a modern UI, but heavy and not focused on network speed |
| [matryer/bitbar](https://github.com/matryer/bitbar) ✅ | Menu bar plugin platform, can print any metric from a script | Requires writing a plugin script — not ready to use out of the box |
| [swiftbar/SwiftBar](https://github.com/swiftbar/SwiftBar) ✅ | The actively maintained fork of BitBar | Same as above |
| [vergoh/vnstat](https://github.com/vergoh/vnstat) ✅(index-verified) | Command-line traffic statistics (per interface / per period) | No GUI, terminal only |
| [zhongyang219/TrafficMonitor](https://github.com/zhongyang219/TrafficMonitor) ✅(index-verified) | Windows taskbar traffic monitor | Wrong platform (Windows) |
| [apple/sample-food-truck](https://github.com/apple/sample-food-truck) | Apple's official `MenuBarExtra` sample | Just a code sample |
| iStat Menus / CleanMyMac and other commercial apps | Closed source, do everything | Paid license |

**Conclusion:** the ecosystem has "general purpose monitors" and "plugin platforms", but **nothing lightweight and dedicated to a live network speed in the menu bar**.
Given that this is a personal tool that needs no GUI beyond the menu and no pile of charts, the project was implemented from scratch in the "minimal but clean" direction — roughly 300 lines of code.

## 2. Design

### 1. How the data is collected

The macOS kernel keeps cumulative counters for every network interface in its `if_data` structure:

- `ifi_ibytes`: cumulative bytes received
- `ifi_obytes`: cumulative bytes sent

`getifaddrs()` is used to walk the interfaces, the two fields of `if_data` are read from `ifa_data`, and two consecutive samples are differenced:

```
speed (bytes/sec) = (cumulative bytes received now - before) / sampling interval
```

Advantages: no polling overhead (it generates no extra network traffic), no administrator rights, no driver dependency.

### 2. Interface selection (avoiding double counting)

If the machine has Wi-Fi (`en0`), a VPN tunnel (`utun*`), a loopback (`lo0`) and bridges (`bridge*`) at the same time, the same traffic is **counted multiple times**.
The menu offers three accounting scopes:

- **Automatic** (default): excludes `lo/awdl/llw/utun/ppp/ipsec/bridge/vlan/gif/stf` and counts physical interfaces only
- **All interfaces**: every UP interface except `lo0` (double counted — useful for troubleshooting)
- **Primary interface**: the first existing one of `en0/en1/...`

### 3. User interface

The menu bar label is **fixed width** (monospaced font, so the menu bar width never changes when the number of digits changes):

```
↓ 36.2M ↑  1.4M
```

> See the [screenshot](#screenshot) above for the real thing.

Implementation details (this is what makes it "never jump"):

- The label uses an AppKit `NSStatusItem` (`NSStatusItem.variableLength`); its width follows the size of the label image
- The image is drawn with the monospaced font `NSFont.monospacedSystemFont`, so character positions are constant
- Values are padded with `%5.1f` plus a unit to exactly 6 characters (`  3.0K` / ` 36.2M` / `999.9M`), so the unit letter always sits in the same column
- As long as the **number of characters is fixed**, the label width is constant: measured 54 pt for download only and 114 pt with upload, independent of the number of digits
- When **"Show upload speed" is unchecked, the whole upload block (including the `↑` arrow) disappears** and leaves no gap — the label shrinks from 114 pt back to 54 pt; re-enabling it restores exactly 114 pt

> Why not SwiftUI's `MenuBarExtra`: in practice `MenuBarExtra` ignores `.font(design: .monospaced)` and `.frame(width:)` on the label and measures the text with a **proportional** font, so as soon as the number of digits changes the whole text block changes width and pushes the icons next to it around (measured 17 px of drift). Switching to `NSStatusItem` + monospaced font + fixed-width values eliminated it completely.

Clicking opens an `NSMenu`:

- Current download / upload speed (`1.2 MB/s`)
- **Interface details** submenu: per-interface download and upload speeds
- Accounting scope, refresh interval (1/2/5 seconds), whether to show the upload speed
- Launch at login (`SMAppService`)
- Quit

Settings are persisted with `UserDefaults`.

### 4. Project layout

```
Sources/NetSpeed/
├── main.swift              # entry point (AppKit, --report command line self-check)
├── AppDelegate.swift       # NSStatusItem + NSMenu UI and menu
├── StatusLabelRenderer.swift# label image rendering (monospaced, width adapts to content)
├── SpeedMonitor.swift      # timed sampling, differencing, interface filtering
├── NetworkReader.swift     # reads kernel counters via getifaddrs
├── ByteFormatter.swift     # byte formatting (fixed-width and human readable)
├── HeadlessReport.swift    # command line self-check mode: --report
└── LoginItem.swift         # launch at login
Scripts/build-app.sh        # packages NetSpeed.app (ad-hoc signature)
```

## 3. Build and usage

### Download and install

Grab `NetSpeed-v1.0.0.zip` from [Releases](https://github.com/yifas/netSpeed/releases) (it contains `NetSpeed.app`):

```bash
unzip NetSpeed-v1.0.0.zip
cp -R NetSpeed.app /Applications/
open /Applications/NetSpeed.app
```

> The app is ad-hoc signed (not notarized by Apple). If macOS complains that "the developer cannot be verified",
> click "Open Anyway" in **System Settings → Privacy & Security**,
> or run `xattr -dr com.apple.quarantine NetSpeed.app` first.

### Build it yourself

```bash
# build and produce dist/NetSpeed.app
./Scripts/build-app.sh

# run
open dist/NetSpeed.app

# install into /Applications
cp -R dist/NetSpeed.app /Applications/
```

Command line self-check (verifies that sampling works):

```bash
.build/release/NetSpeed --report 5
```

Real-world calibration: while downloading from a USTC mirror `curl` averaged 39 MB/s and NetSpeed sampled 24.8 / 50.8 / 45.5 / 40.6 MB/s per second (instantaneous values inside a 1 second window), matching the real link.

## 4. Known limitations and fix log

- The speed is an **instantaneous value of the current sampling window**, not a sliding average; increase the interval or add exponential smoothing if you need it
- macOS 13+ (developed on macOS 15.8.2)

### Fixed

1. **Menu bar width jitter (icons jumping left and right)**:
   - The first version used SwiftUI `MenuBarExtra`; it ignores the monospaced font and fixed width on the label and measures with a proportional font →
     as soon as the number of digits changed (`3.0K` → `36.2M`) the text block width changed and pushed the neighbouring icons around (measured 17 px of drift)
   - Fix: switched to AppKit `NSStatusItem` + a label image whose width is derived from the **actual text width**, with monospaced font and fixed-width values,
     so the width no longer depends on the number of digits
   - Verification: over 12 consecutive samples (the speed jumping between `3.0K` and `17.0K`/`320.4K`),
     the label left edge stayed at px 1602-1616 and the neighbouring icon at px 1870-1905 — **zero drift**
2. **Occasional crash** (`EXC_BREAKPOINT`): when an interface counter wrapped around or was reset, `UInt64` subtraction wrapped into a huge value
   and `Int64(bytesPerSecond)` triggered a Swift runtime trap → changed to saturating subtraction (a wrap counts as 0) +
   a speed clamp (1 TB/s) + one more defensive check inside the formatting functions
3. **Empty space on the right after unchecking "Show upload speed"**:
   - The label used to be one fixed 116 pt wide image; with the upload speed hidden it was padded with trailing spaces, leaving a visible gap
   - Fix: the label image is now generated with its **actual text width** (`NSStatusItem.variableLength`),
     so the upload block is not drawn at all and the width shrinks from 114 pt to 54 pt; re-enabling it restores exactly 114 pt
