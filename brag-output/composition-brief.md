# Hyperframes Composition Brief: Topsoil

## Objective
Create a short, premium SaaS launch-style brag video for Topsoil.

## Output
- Composition directory: `brag-output/composition/`
- Rendered video: `brag-output/brag.mp4`
- Format: landscape — 1920x1080
- Duration: 18.0 seconds

## Source Material
- Project root: `/Users/davey/MyProjects/Topsoil`
- Primary files read: `README.md`, `website/index.html`, `website/assets/`
- Product name: Topsoil
- Tagline / strongest claim: "Your notch is now the best part of your screen."
- Key UI or visual moments to recreate:
  - MacBook top display bezel with the centered camera notch
  - Live notch expansion into the frosted glass dashboard (Now Playing, Quick Toggles, Drop Shelf)
  - Code Page docking 3 live coding agent terminal panes (Claude Code, Codex CLI, Cursor CLI)
  - Notch Garden pixel art bloom card
- Copy that must appear verbatim:
  - "Your notch is now the best part of your screen."
  - "Everything, one glance away."
  - "Three agents, one bar."
  - "Claude · Codex · Cursor"
  - "Topsoil grows a garden in your notch."
  - "Swift 6 · No Electron · Local by default"

## Creative Direction
- Tone preset: polished
- Creative direction: clean premium Apple-grade SaaS launch film
- Interpretation: Restraint, fluid spring physics, confident typography, precision UI cards, Apple-grade hardware framing.
- Angle: Turning the MacBook notch from a tolerated cutout into the primary developer hub.
- Hook: The camera notch waking up and expanding on click (0.0s - 3.82s).
- Outro / punchline: "Topsoil. Swift 6 · No Electron · Local by default."
- Avoid:
  - Generic SaaS hype words ("streamline your workflows", "synergy")
  - Abstract filler graphics
  - Cluttered motion that obscures real UI readability

## Visual Identity
- Background: `#f6f7f9` (frosted metallic sheen `#fafbfc` to `#eceef2`)
- Hardware bezel: `#101014` with `#2a2a30` border
- Accent: `#15803d` (emerald green)
- Text / Ink: `#18181b` (headings), `#52525b` (body), `#8e8e96` (muted)
- Display font: `-apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif`
- Mono font: `ui-monospace, "SF Mono", Menlo, monospace`
- Visual assets from project:
  - `website/assets/hero_screen.webp`
  - `website/assets/panel_quick.webp`
  - `website/assets/panel_code.webp`
  - `website/assets/garden.webp`
  - `website/assets/logo.svg`

## Storyboard
1. Scene 1 — The Notch Hook (0.0s - 3.82s): MacBook top bezel, notch centered, headline "Your notch is now the best part of your screen." Cursor clicks notch at 2.2s.
2. Scene 2 — The Live Dashboard (3.82s - 8.74s): Notch expands downward into the full Topsoil dashboard. "Everything, one glance away."
3. Scene 3 — Three Agents, One Bar (8.74s - 13.11s): Code page panes (Claude, Codex, Cursor) dock live with status badges, accompanied by the Notch Garden pixel card.
4. Scene 4 — Outro Lockup (13.11s - 18.00s): Panel folds back into notch. Crisp Topsoil logo, specs, and download CTA.

## Audio
- Audio role: Steady, warm, confident business electronic bed with crisp interface clicks and a resonant outro mark.
- Audio arc: Ambient opening, groove kicks in as notch opens, rhythmic sync on agent cards, clean resonant bell on final logo.
- Music: `happy-beats-business-moves-vol-12-by-ende-dot-app.mp3`
- Music treatment: Starts at 0.0s at volume 0.32, builds steadily, fades from 16.5s to 18.0s.
- Music cue guidance: Preset cues loaded from `happy-beats-business-moves-vol-12-by-ende-dot-app.music-cues.json`.
  - 3.82s: Beat lock (notch opens)
  - 8.74s: Strong cue lock (Three agents arrive)
  - 13.11s: Strong cue lock (Outro brand mark lands)
  - 17.47s: Final cue before fade
- Audio-reactive treatment: Subtle; background depth and card aura modulate gently with music RMS energy.
- Audio-coupled moments:
  - 2.20s: Cursor clicks notch (`assets/sfx/interface/click_002.ogg`)
  - 3.82s: Panel drops open (`assets/sfx/interface/drop_001.ogg`)
  - 9.29s, 9.83s, 10.37s: Agent terminal cards click in (`assets/sfx/interface/click_002.ogg`)
  - 13.11s: Topsoil logo slam / bell payoff (`assets/sfx/impact/impactBell_heavy_000.ogg`)
- Audio files:
  - `assets/music/happy-beats-business-moves-vol-12-by-ende-dot-app.mp3`
  - `assets/sfx/interface/click_002.ogg`
  - `assets/sfx/interface/drop_001.ogg`
  - `assets/sfx/impact/impactBell_heavy_000.ogg`

## Hyperframes Instructions
- Composition directory: `brag-output/composition/`
- Top-level `index.html` with root `data-composition-id="topsoil-brag"`, `data-width="1920"`, `data-height="1080"`, `data-duration="18"`.
- Paused timeline registered at `window.__timelines["topsoil-brag"]`.
- Validated via `npx hyperframes check` and rendered to `brag-output/brag.mp4`.
