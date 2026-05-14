# Lexy Files - Windows Design Specification

Derived from pixel-level analysis of four Windows design mockups:
`home.png`, `transfer.png`, `devices.png`, `files.png` in `design/windows/`.

## Color Palette

| Token | Hex | Purpose |
|---|---|---|
| `--bg-page` | `#051424` | Page / app background (dominant in content regions) |
| `--bg-deep` | `#001020` | Bucketed content background (page + shadow) |
| `--bg-surface` | `#122131` | Cards, sidebar, elevated panels |
| `--bg-surface-2` | `#102030` | Sidebar/row surface variant |
| `--bg-surface-3` | `#172737` | Upper card tint (devices.png card #1) |
| `--border-subtle` | `#203040` | Dividers, row borders |
| `--border-strong` | `#103040` | Card borders / inner dividers |
| `--accent` | `#00F0FF` | Primary cyan (buttons, active states, focus) |
| `--accent-600` | `#00D0E0` | Hover/pressed cyan |
| `--accent-800` | `#008090` | Deep cyan (shadows/strokes) |
| `--accent-900` | `#006070` | Darkest cyan used |
| `--text-primary` | `#D0E0F0` | Titles, card text |
| `--text-secondary` | `#8B9BAE` | Labels, meta, captions |
| `--text-tertiary` | `#6B7280` | Disabled / very subtle text |

## Global Layout

All screens use a fixed left sidebar + top bar + content area.

| Screen | Image size | Sidebar width | Top bar height | Hero band (below top bar) |
|---|---|---|---|---|
| home.png | 1623 x 1061 | 309 px | 595 px (hero+topbar merged: large pickup-code card dominates) | y=595-635 |
| transfer.png | 1585 x 1067 | 269 px | 50 px | y=50-90 |
| devices.png | 1448 x 1149 | 292 px | 54 px | y=54-94 |
| files.png | 1553 x 1025 | 226 px | 40 px | y=40-80 |

Variation in sidebar width (226-309) across mockups suggests the sidebar is
fluid; for implementation use a single canonical width. Recommended:

- Sidebar: **260 px**
- Top bar: **48 px** (home has a dedicated hero card on top so topbar appears larger)
- Hero band: **40 px** below top bar
- Content padding: **24 px** left/right, **20 px** top

## Sidebar

- Background: `#102030` (approx `--bg-surface-2`)
- Full-height fixed column on the left
- **Active nav item is a full-width cyan pill**, not a thin left accent bar
  - Measured cyan pill rectangles per screen:
    - home:     y=126..181 (h=56), x=29..277 (w=249)
    - transfer: y=123..163 (h=41), x=22..242 (w=221)
    - devices:  y=130..175 (h=46), x=23..251 (w=229)
    - files:    y=99..141 (h=43),  x=16..202 (w=187)
  - Margin from sidebar edges: ~12-30 px horizontal
  - Pill radius: ~10 px
  - Fill: solid `#00F0FF` (analysis shows `#00F0F0` bucketed cyan dominates active-state crops)
- Inactive items: icon in `--text-secondary`, text in `--text-primary`
- Brand / logo block sits at the top of the sidebar (cyan cluster detected at top of every sidebar)

## Top Bar

- Background: `#001020` (the deep-bucket variant of page bg)
- Height: **40-54 px** (use 48 px)
- Contains (left to right): page title / breadcrumbs, then search/actions on the right
- The home screen reserves the whole top region (595 px) for a large pickup-code hero card - see Home section

## Content area

- Background: `#051424` / `#001020` (page bg)
- Starts immediately right of the sidebar
- Cards are placed on top of the page bg with `--bg-surface` (`#122131`) fills

## Components

### Primary button (cyan)
- Fill: `#00F0FF`
- Text: dark (`#051424` or near-black)
- Radius: ~8 px (rounded)
- Example observed on home.png: 160 x 44 px pill near hero (x=568..728, y=448..492)

### Secondary button
- Transparent fill, 1 px cyan border, cyan text
- Same radius/height as primary

### Card
- Fill: `#122131` (or `#172737` for slightly brighter surfaces)
- Radius: ~12-16 px
- Padding: 20-28 px
- Subtle 1 px inner stroke in `#203040` on some cards
- Shadow: none/very subtle (dark-on-dark)

### Pill / Badge
- Small cyan-filled rounded rectangles ~60-130 x 12-16 px appear on devices/files screens
- Likely used for status (Online, Connected) and action chips

### Text hierarchy
- Headline: `#D0E0F0`, 22-28 px, weight 600-700
- Body / item title: `#D0E0F0`, 14-16 px
- Meta / caption: `#8B9BAE`, 12-13 px

## Screens

### 1. Home (`home.png`, 1623 x 1061)

Sidebar: 309 px | Top band: 595 px (contains hero)

Layout (top to bottom inside content area):

1. **Pickup code hero card** - the defining element of this screen.
   - Fills the whole top band (content width x ~550 px tall).
   - Background: `#102030` card on the `#051424` page.
   - Center stack: small label (e.g. "Your pickup code"), then a very
     large numeric/alphanumeric code rendered in `--text-primary`, then
     helper text in `--text-secondary`.
   - One primary cyan pill button (~160 x 44 px) near the bottom-center
     of the card - detected cyan cluster at y=448..492.
   - Small cyan icon at the right of the card (~16x16) at (396,284..412,300).
2. **Secondary card** below the hero (y=683..803, ~120 px).
   - Recent transfers or status row.
   - Background `#122131`.

Unique component: **pickup code display**. Use a monospace or tabular
sans serif, letter-spacing positive, in `--text-primary`.


### 2. Transfer (`transfer.png`, 1585 x 1067)

Sidebar: 269 px | Top bar: 50 px | Hero: y=50..90

Layout:

1. **Top bar / page header** - title "Transfer" + actions on the right.
2. **Mode tabs** at the top of the content area (high text density at y=90..170).
   - Likely two/three tabs: Send / Receive / History.
   - Active tab: cyan underline or filled cyan pill behind the label.
   - Cyan cluster at (336,228..404,328) suggests a centered upload/QR icon block.
3. **Form / drag-drop area** - empty deep-navy region in the middle.
4. **Card #1** y=462..552 (~90 px) - probably a recipient/code input row.
5. **Card #2** y=588..672 (~84 px) - a secondary action card or settings row.

Unique component: **transfer mode tabs** (segmented control) and a large
central drop-target with an upload glyph in cyan.


### 3. Devices (`devices.png`, 1448 x 1149)

Sidebar: 292 px | Top bar: 54 px | Hero: y=54..94

Layout:

1. **Page header** - "Devices" title, primary cyan button on the right (add / pair device).
2. **Device card #1** y=226..412 (~186 px, fill `#172737`).
   - Horizontal card layout: device icon/avatar on the left, name + status
     stack in the middle, action buttons on the right.
   - Status indicator (small cyan dot or pill) detected near (948,300..980,328).
   - Action chip / pill detected at (1156,372..1220,376) - 64 x 4 bounding
     box implies a thin horizontal link or underline style action.
3. **Device card #2** y=448..754 (~306 px, fill `#122131`).
   - Taller - may be the selected/expanded device showing detail rows
     (storage, recent files, permissions).
   - Contains multiple inner rows (text-density spikes at y=454..614, 654..734).

Unique component: **device card row** with avatar, name, status chip, and trailing action button.


### 4. Files (`files.png`, 1553 x 1025)

Sidebar: 226 px | Top bar: 40 px | Hero: y=40..80

Layout:

1. **Page header** y=80..160 - title "Files", search input and view toggle on the right.
2. **Summary card / filter row** y=176..374 (~198 px, fill `#122131`).
   - Contains breadcrumb / category chips across the top (cyan cluster at (276,232..388,244), 112x12 px).
   - Storage indicator or active filter pill in the upper-right (cluster at (1304,276..1328,308)).
3. **File list/table** y=416..980 (~564 px) on page bg `#051424`.
   - Header row around y=200..240.
   - Rows ~40-48 px each separated by 1 px `#203040` dividers.
   - Column layout: icon | name | size | modified | actions.
   - High text-density bands at y=280..360, 480..600 confirm repeating rows.
4. **Footer / status strip** y=992..1010 (~18 px).

Unique component: **file row** with leading icon, primary text, right-aligned meta columns, and hover-revealed actions.


## Cross-screen summary (measured)

```
file          WxH         sidebar_w  topbar_h  hero_bottom_y
home.png      1623x1061   309        595       635
transfer.png  1585x1067   269        50        90
devices.png   1448x1149   292        54        94
files.png     1553x1025   226        40        80
```

## Implementation tokens (recommended)

```css
:root {
  --bg-page:        #051424;
  --bg-deep:        #001020;
  --bg-surface:     #122131;
  --bg-surface-2:   #102030;
  --bg-surface-3:   #172737;
  --border-subtle:  #203040;
  --border-strong:  #103040;
  --accent:         #00F0FF;
  --accent-600:     #00D0E0;
  --accent-800:     #008090;
  --accent-900:     #006070;
  --text-primary:   #D0E0F0;
  --text-secondary: #8B9BAE;
  --text-tertiary:  #6B7280;
  --sidebar-width:  260px;
  --topbar-height:  48px;
  --radius-card:    14px;
  --radius-pill:    999px;
}
```
