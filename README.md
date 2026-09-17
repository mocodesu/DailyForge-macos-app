<div align="center">

<img src="docs/icon.png" width="140" alt="DailyForge icon">

# 🔥 DailyForge

**A macOS discipline tool that helps you build a daily exercise habit — and keeps you honest about it.**

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.10-orange?style=flat-square&logo=swift)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-blue?style=flat-square&logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![SwiftData](https://img.shields.io/badge/SwiftData-purple?style=flat-square&logo=swift)](https://developer.apple.com/xcode/swiftdata/)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)

You define a fixed set of daily exercises. Every day they reset.
You complete them, swear by voice that you actually did the work, and the day is sealed.
Miss it, and DailyForge reminds you, nags you, and finally floods your screen with a pulsing red overlay until the work is done.

*It's not a workout tracker. It's a workout **enforcer**.*

</div>

---

## ✨ Features

<table>
<tr>
<td width="50%" valign="top">

### 🏋️ Daily exercise loop
- **Create once, do them forever** — reps, sets, and durations lock at creation
- **Automatic daily reset** — fresh list every calendar day, full history preserved
- **Two exercise types** — rep-based or timed
- **Multi-part tagging** — Chest, Back, Shoulders, Arms, Core, Legs, Glutes, Full Body, Cardio
- **Minimum 5 per day** — no coasting on a single exercise

</td>
<td width="50%" valign="top">

### ⏱️ Commitment timer
- **Session timer per exercise** — set at creation, cannot be changed
- **Full-screen and unskippable** — no pause, no cancel
- **Sound feedback** — pop on start, tick every second, chime at zero
- **Only way out** is to let it run and press **Mark Done**

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🎤 Voice swear
- **Every day requires a spoken oath**
- **On-device speech recognition** — nothing leaves your Mac
- **No live transcript** — you review what was heard only after stopping
- **Customizable phrase** — default is a clear, unambiguous promise
- **Mandatory** — the day cannot be locked without a valid swear

</td>
<td width="50%" valign="top">

### 📊 History & stats
- **30-day circle grid** — each day a ring, color-coded by completion
- **Session summary** — total time, work time, break time
- **Per-exercise breakdown** — start, finish, and duration for each
- **Streak counter** — consecutive fully-completed days
- **Tap any circle** for a full day report

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🛡️ Enforcement
- **Daily reminder** — set a time, get a notification
- **Grace period** — 15 minutes to comply, then the gloves come off
- **Red overlay** — pulsing tint covers every screen, blocks clicks below
- **Unquittable** — Cmd+Q, Cmd+W, red close button all disabled
- **Menu bar and Dock hidden** — no escape hatches
- **Auto-relaunch** — force-quit only buys you 15 minutes

</td>
<td width="50%" valign="top">

### 💾 Data safety
- **Rolling backups** — 14-day window, taken before the app touches anything
- **Manual backup / restore / export** — all inside Preferences → Data
- **JSON export** — your entire dataset, human-readable
- **Schema-change resilience** — no silent wipes
- **Zero telemetry** — no accounts, no servers, no network code

</td>
</tr>
</table>

---

## 🎨 Interface

<p align="center">
  <em>Adaptive theming. Real exercise icons. Contrast-tuned for both light and dark mode.</em>
</p>

| 🌗 | Light Mode | Dark Mode |
|:--:|:---|:---|
| **Window** | Warm cream `#FAF8F4` | Icon navy `#1C1F2E` |
| **Cards** | Pure white | Lighter navy `#252A3D` |
| **Accent** | Deep orange `#C2410C` | Bright flame `#FF6B35` |
| **Success** | Deep green `#15803D` | Bright green `#4ADE80` |
| **Warning** | Amber `#B45309` | Bright amber `#FBBF24` |
| **Danger** | Deep red `#B91C1C` | Bright red `#F87171` |

> Every text-on-surface pair hits **≥4.5:1** — WCAG AA compliant in both modes.

---

## 📋 Requirements

| | |
|:--|:--|
| ![macOS](https://img.shields.io/badge/-macOS%2014%2B-black?style=flat-square&logo=apple) | Sonoma or later |
| ![Xcode](https://img.shields.io/badge/-Xcode%2016%2B-147EFB?style=flat-square&logo=xcode) | To build from source |
| ![Microphone](https://img.shields.io/badge/-Microphone-FF6B35?style=flat-square) | Required for the voice swear |
| ![Speech](https://img.shields.io/badge/-Speech%20Recognition-4ADE80?style=flat-square) | Granted on first run |

---

## 🚀 Installation

### 📦 Build from source

**1.** Clone the repository
```bash
git clone https://github.com/yourusername/DailyForge.git
cd DailyForge
