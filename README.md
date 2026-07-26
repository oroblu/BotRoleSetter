# CMaNGOS BotRoleSetter Addon

*Client-side addon for quick bot role & talent spec setup — GossipFrame-style UI with spec dropdown.*

[![Version](https://img.shields.io/badge/version-6.0-blue)](.)
[![WoW](https://img.shields.io/badge/wow-1.14.x%20Classic-yellow)](.)
[![License](https://img.shields.io/badge/license-MIT-green)](.)

## What It Does

Manually whispering `talents pve prot`, `.bot init`, `co +tank`, etc. to every bot is tedious. This addon automates the whole setup:

1. **Target a bot** (or open `/brs` while in a party — auto-selects the first member)
2. **Pick a role** — Tank, Healer, or Dps (unavailable roles are greyed out)
3. **Choose a talent spec** from the dropdown (76 specs from `aiplayerbot.conf`)
4. **Click Apply** — queues 7 commands via whisper at 1-second intervals

## Quick Start

```
/brs                    ← toggle the window
target a bot            ← or join a party and /brs auto-selects
click Tank/Healer/Dps   ← pick a role
choose spec in dropdown ← pick the exact talent spec
click Apply             ← send all commands
click Query             ← send "talents" whisper to see bot's current spec
```

## Commands

| Command | Description |
|---------|-------------|
| `/brs` | Open/close the BotRoleSetter window |
| **Apply** button | Send the full 7-command sequence to the selected bot |
| **Query** button | Whisper `talents` to the bot (bot replies with its current spec) |

### Command Sequence (Apply)

Sent via whisper, 1 second apart:

| # | Command | Purpose |
|---|---------|---------|
| 1 | `talents <spec>` | Apply the selected talent spec |
| 2 | `.bot init <name> rare` | Initialize gear + default strategies |
| 3 | `reset strats` | Recalculate strategies on the new spec |
| 4 | `nc -quest,-loot,+ai chat,-grind` | Non-combat layer |
| 5 | `follow` | Bot follows the master |
| 6 | `summon` | Summon the bot |
| 7 | `co +<role>,-cc,-behind` | Combat layer (+tank/+heal also get `-dps`) |

## UI Overview

```
┌────────────── 384px ──────────────┐
│  [Icon]  Botname (Class)     [X]  │
│                                    │
│  ┌───── ScrollFrame 300×334 ────┐ │
│  │  Greeting text          [↑]  │ │
│  │                         [█]  │ │
│  │   [Tank] [Healer]       [↓]  │ │
│  │        [Dps]                  │ │
│  │                               │ │
│  │  [pve prot           ▾]      │ │  ← spec dropdown
│  │                               │ │
│  │       [ Query ]               │ │
│  │       [ Apply ]               │ │
│  └───────────────────────────────┘ │
│                              [Close]│
└────────────────────────────────────┘
```

**Key details:**

- **Title** — shows the selected bot's name and class on one line: `Botname (Class)`. White, same font as greeting text.
- **Icon** — class icon with circular mask (like GossipFrame portrait), 46×46.
- **Role buttons** — `UIPanelButtonTemplate` with role icons. Selected role is highlighted. Unavailable roles are disabled per-class.
- **Spec dropdown** — `UIDropDownMenuTemplate` populated dynamically from class+role. Click anywhere on the dropdown to open.
- **Query** — sends `talents` whisper so the bot reports its current spec.
- **Apply** — sends the full 7-command sequence.
- `/brs` in party auto-selects the first group member.
- `/brs` outside party shows: *"You are not in party, invite your bots"*.

## Installation

1. Copy `BotRoleSetter/` into your AddOns folder:
```
World of Warcraft\_classic_\Interface\AddOns\BotRoleSetter\
```
2. Restart WoW or reload UI (`/reload`)
3. You should see `[BotRoleSetter] /brs to toggle...` in chat ✔

## Server Configuration

```ini
# aiplayerbot.conf
# Must be set to "full" so talents actually allocate points
# before .bot init reads GetPlayerSpecTab().
# With "no", Warriors default to tab=2 (Protection) → wrong gear.
AiPlayerbot.AutoPickTalents = full
```

## Requirements

- **CMaNGOS** with the **playerbots** module (ike3 or similar)
- **WoW Classic 1.14.x** client (Interface 11400)
- Player with **whisper permissions** (GM or appropriately ranked)

## Troubleshooting

**"Apply talents [spec] talent link is invalid":**
The spec names in this addon come from `spp-classics-cmangos` default config (`Settings/vanilla/aiplayerbot.conf`). Your server may use different spec names. Run `/w <botname> talents list` on a bot to see the actual spec names available, then update the `TALENTS` table in `BotRoleSetter.lua` accordingly.

**"You are not in party, invite your bots":**
You're not in a party and have no player target. Join a party or manually target a bot, then open `/brs`.

**Dropdown shows "Role not available":**
The selected class doesn't have that role — e.g., Warrior can't be Healer, Mage can't be Tank. Pick a different role.

**Window opens but shows old bot info:**
Target a bot or toggle `/brs` twice — the window refreshes from current group/target state on each open.

## License

MIT — do whatever you want with it.

## Credits

Built on the [SPP Classics CMaNGOS](https://github.com/celguar/spp-classics-cmangos) ecosystem. UI patterns from the GossipFrame (`UI-QuestGreeting-*` textures, `UIPanelScrollFrameTemplate`, portrait mask). Spec data from `Settings/vanilla/aiplayerbot.conf`.
