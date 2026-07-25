# BotRoleSetter

Addon for CMaNGOS Playerbots — quick bot role setup with vanilla GossipFrame-style UI.

## Features

- Automatic target class detection
- Role selection: **TANK** | **HEALER** | **DPS**
- Talent specs from `aiplayerbot.conf.dist.in`
- Send commands via whisper to the target bot
- Full GossipFrame-style UI (384×512)

## UI Structure

```
┌─────────────── 384px ───────────────┐
│  [Icon]  Class Name            [X]  │  ← portrait + name + close
│                                      │
│  ┌──────── ScrollFrame ───────────┐ │
│  │  Target a player bot, pick     │ │  ← scrollable greeting text
│  │  a role, click APPLY.     [↑] │ │
│  │                            [█] │ │
│  │     [TANK] [HEALER]       [↓] │ │  ← role buttons (siblings,
│  │        [DPS]                    │ │    overlap the scroll area)
│  │                                │ │
│  │           Role:                │ │  ← centered status text
│  │     TANK (pve prot)            │ │    (two lines, between buttons and APPLY)
│  │                                │ │
│  │         [ APPLY ]              │ │  ← action button (inside scroll area)
│  │                                │ │
│  └────────────────────────────────┘ │
└──────────────────────────────────────┘
```

**Key pattern:** The role buttons and APPLY are children of the main frame, NOT the `scrollChild`. This allows them to be positioned overlapping the ScrollFrame area — they render on top (DrawLayer + creation order). The role text is a FontString centered between the buttons and APPLY, on two lines (`Role:\nTANK (pve prot)`).

## Concepts Demonstrated

- **ScrollFrame** (`UIPanelScrollFrameTemplate`) with scrollable greeting text
- **Scroll activated only when text exceeds the visible area** (`UpdateScrollChildRect` + `GetStringHeight`)
- **Scrollbar positioning** GossipFrame style (anchored to the right edge)
- **Mouse wheel** routed through the scrollbar
- **Conflict-free anchoring**: `TOPLEFT` + `TOPRIGHT` (same Y) instead of `TOPLEFT` + `RIGHT` (conflicting Y)
- `UIPanelButtonTemplate` with side icons and shifted text
- `LockHighlight`/`UnlockHighlight` for selected role state
- `Enable`/`Disable` for roles unavailable for the class
- `C_Timer.After` for sequential command sending via whisper
- `SetShown` pattern for toggle slash command
- `UI-QuestGreeting-*` corner textures + `UI-Quest-BotLeftPatch` patch

## Installation

Copy the `BotRoleSetter/` folder into `World of Warcraft\_classic_\Interface\AddOns\`

## Commands

- `/brs` — Open/close the window

# 
