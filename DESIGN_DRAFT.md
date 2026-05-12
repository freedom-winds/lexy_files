# Lexy Files - Modern UI Design Draft

## Design Philosophy
**Goal**: Create a modern, clean, and professional file transfer app that feels premium and trustworthy.

**Inspiration**: Notion, Linear, Arc Browser - apps known for their polished, minimal interfaces.

---

## Color Palette

### Primary Colors
```
Primary (Brand): #6366F1 (Indigo 500) - Modern, trustworthy, tech-forward
Primary Dark: #4F46E5 (Indigo 600)
Primary Light: #A5B4FC (Indigo 300)
Primary Subtle: #EEF2FF (Indigo 50)
```

### Accent Colors
```
Success: #10B981 (Emerald 500) - Fresh, positive
Warning: #F59E0B (Amber 500) - Attention-grabbing
Error: #EF4444 (Red 500) - Clear danger signal
Info: #3B82F6 (Blue 500) - Informative
```

### Neutral Colors
```
Background: #FAFAFA (Warm gray, not pure white)
Surface: #FFFFFF (Pure white for cards)
Surface Elevated: #FFFFFF with shadow
Border: #E5E7EB (Gray 200)
Text Primary: #111827 (Gray 900)
Text Secondary: #6B7280 (Gray 500)
Text Tertiary: #9CA3AF (Gray 400)
```

---

## Typography

### Font Family
```
Primary: 'Inter' or system default (-apple-system, SF Pro, Segoe UI)
Monospace: 'JetBrains Mono' or 'SF Mono' for codes
```

### Font Sizes & Weights
```
Display: 32px / Bold (800)
H1: 24px / Bold (700)
H2: 20px / Semibold (600)
H3: 16px / Semibold (600)
Body: 14px / Regular (400)
Body Small: 13px / Regular (400)
Caption: 12px / Medium (500)
Tiny: 11px / Medium (500)
```

---

## Spacing System
```
xs: 4px
sm: 8px
md: 12px
lg: 16px
xl: 24px
2xl: 32px
3xl: 48px
```

---

## Component Design

### 1. Cards
```
Style: Elevated cards with subtle shadows
Border Radius: 12px (more modern than 8px)
Padding: 16px
Shadow: 0 1px 3px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.04)
Hover: Lift slightly with deeper shadow
Background: Pure white (#FFFFFF)
Border: None (shadow provides separation)
```

### 2. Buttons

**Primary Button**
```
Background: Linear gradient from Primary to Primary Dark
Color: White
Padding: 12px 20px
Border Radius: 10px
Font: 14px / Semibold (600)
Shadow: 0 2px 8px rgba(99,102,241,0.25)
Hover: Lift + deeper shadow
Active: Scale down slightly (0.98)
```

**Secondary Button**
```
Background: Surface with border
Border: 1.5px solid Border color
Color: Text Primary
Hover: Background to Primary Subtle
```

**Ghost Button**
```
Background: Transparent
Color: Primary
Hover: Background to Primary Subtle
```

### 3. Input Fields
```
Background: Surface
Border: 1.5px solid Border
Border Radius: 10px
Padding: 12px 14px
Font: 14px
Focus: Border color to Primary, subtle glow shadow
Placeholder: Text Tertiary
```

### 4. Navigation

**Bottom Navigation (Mobile)**
```
Background: Surface with blur effect (backdrop-filter)
Height: 64px
Border Top: 1px solid Border
Shadow: 0 -2px 16px rgba(0,0,0,0.04)
Icons: 24px, filled when active
Labels: 11px / Medium
Active Color: Primary
Inactive Color: Text Secondary
Active Indicator: Pill shape background in Primary Subtle
```

**Navigation Rail (Desktop)**
```
Width: 72px
Background: Surface
Border Right: 1px solid Border
Icons: 24px
Active: Full-width pill background in Primary Subtle
Hover: Subtle background
```

### 5. Status Pills
```
Border Radius: 999px (fully rounded)
Padding: 4px 10px
Font: 11px / Semibold (600)
Background: Color at 10% opacity
Text: Full color
Icon: 12px, same color
```

### 6. File/Device Cards
```
Layout: Horizontal with icon, content, actions
Icon: 48px rounded square with gradient background
Icon Border Radius: 12px
Content: Name (14px/Semibold) + metadata (12px/Regular/Secondary)
Actions: Ghost icon buttons
Spacing: 14px between elements
Hover: Lift card slightly
```

### 7. Progress Bars
```
Height: 6px
Border Radius: 999px
Background: Border color
Fill: Linear gradient Primary to Primary Light
Animation: Smooth transition, shimmer effect for indeterminate
```

### 8. Empty States
```
Icon: 64px, in Primary Subtle circle (96px)
Title: 18px / Semibold
Subtitle: 14px / Regular / Text Secondary
Spacing: Generous (24px between elements)
Action Button: Primary style
```

---

## Screen-Specific Design

### Home Screen
```
Header:
- Large greeting: "Welcome back, [Name]" (24px/Bold)
- Subtitle: "Send files instantly" (14px/Regular/Secondary)
- Background: Subtle gradient from Primary Subtle to Background

Quick Actions:
- Two large cards side-by-side (on desktop)
- Send File: Primary gradient background, white text, upload icon
- Receive File: White background, border, Primary text, download icon
- Each card: 160px height, centered content, large icon (32px)

Recent Activity (if authenticated):
- Timeline-style list
- Small file icons with names
- Timestamps on right
- Divider lines between items
```

### Files Screen
```
Header:
- Title + file count badge
- Search bar (prominent, full width on mobile)
- Filter chips: All, Active, Expired

File List:
- Cards with file icon (gradient background)
- File name (14px/Semibold)
- Size + date (12px/Secondary)
- Pickup code in monospace with copy button
- Status pill (Active/Expired)
- Download count with icon
- Delete button (ghost, appears on hover on desktop)
```

### Devices Screen
```
Summary Card:
- Gradient background (Primary to Primary Dark)
- White text
- Large online count (32px/Bold)
- Total devices (14px/Regular)
- Pulse animation on online indicator

Device List:
- Device icon with platform-specific styling
- Device name (14px/Semibold)
- Platform + type (12px/Secondary)
- Online status pill
- Last seen (if offline)
- Remove button (ghost)
```

### Transfer Screen
```
Tabs:
- Segmented control style (not traditional tabs)
- Pill-shaped active indicator
- Smooth sliding animation

Connection Status:
- Banner at top with icon
- Connected: Success color with checkmark
- Disconnected: Warning color with spinner
- Compact height (48px)

Transfer Progress:
- Large progress circle (for active transfers)
- File name in center
- Percentage below
- Speed indicator
- Cancel button

Device List:
- Grid on desktop (2 columns)
- List on mobile
- Device cards with send button
- Online indicator (pulsing dot)
```

---

## Animations & Interactions

### Micro-interactions
```
Button Press: Scale to 0.98, duration 100ms
Card Hover: Translate Y -2px, shadow increase, duration 200ms
Tab Switch: Slide animation, duration 300ms, ease-out
Loading: Skeleton screens with shimmer effect
Success: Checkmark with scale + fade animation
Error: Shake animation (subtle)
```

### Transitions
```
Page Transitions: Fade + slight slide up, duration 250ms
Modal: Fade background + scale modal from 0.95 to 1.0
Toast/Snackbar: Slide up from bottom, duration 300ms
```

---

## Iconography
```
Style: Rounded, consistent stroke width (2px)
Size: 20px (small), 24px (default), 32px (large), 48px (hero)
Color: Inherit from parent or use semantic colors
```

---

## Dark Mode (Future)
```
Background: #0F172A (Slate 900)
Surface: #1E293B (Slate 800)
Border: #334155 (Slate 700)
Text Primary: #F1F5F9 (Slate 100)
Text Secondary: #94A3B8 (Slate 400)
Primary: Lighter shade (#818CF8 - Indigo 400)
```

---

## Implementation Notes

### Shadows
```
sm: 0 1px 2px rgba(0,0,0,0.04)
md: 0 2px 8px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.04)
lg: 0 4px 16px rgba(0,0,0,0.12), 0 2px 4px rgba(0,0,0,0.06)
xl: 0 8px 32px rgba(0,0,0,0.16), 0 4px 8px rgba(0,0,0,0.08)
```

### Gradients
```
Primary: linear-gradient(135deg, #6366F1 0%, #4F46E5 100%)
Success: linear-gradient(135deg, #10B981 0%, #059669 100%)
Subtle: linear-gradient(180deg, #FAFAFA 0%, #FFFFFF 100%)
```

### Border Radius Scale
```
sm: 6px
md: 10px
lg: 12px
xl: 16px
full: 999px
```

---

## Key Improvements Over Current Design

1. **Modern Color Palette**: Indigo instead of teal - more contemporary and professional
2. **Better Contrast**: Improved text hierarchy with proper color weights
3. **Elevated Cards**: Shadows instead of borders for depth
4. **Rounded Corners**: 12px instead of 8px for softer, modern feel
5. **Better Spacing**: More generous padding and margins
6. **Gradient Accents**: Subtle gradients for visual interest
7. **Micro-interactions**: Smooth animations for better UX
8. **Typography**: Clearer hierarchy with proper font weights
9. **Icon Treatment**: Larger, more prominent icons with gradient backgrounds
10. **Status Indicators**: More visual with pills and pulsing dots

This design will make the app feel premium, modern, and trustworthy - like a professional tool rather than a basic utility.
