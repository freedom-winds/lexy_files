# Design Analysis - Current vs. Target (Figma Windows Reference)

## Current State (mobile/ Flutter app)

### Theme (config/theme.dart)
✅ **Already updated** with modern Indigo palette:
- Primary: #6366F1 (Indigo 500)
- Accent: #8B5CF6 (Violet)
- Gradients defined: `heroGradient`, `primaryGradient`, `successGradient`
- Shadows: `shadowSm`, `shadowMd`, `shadowLg`
- Border radii: 8px (sm), 10px (md), 12px (lg), 16px (xl)
- Cards: elevation 2, surfaceTintColor transparent

### Widgets (widgets/app_ui.dart)
✅ **Already updated**:
- `AppIconBadge`: Supports gradient backgrounds with glow shadows
- `StatusPill`: Rounded (999px), 10px/4px padding
- `AppEmptyState`: Large circular icon (96px) in primarySubtle
- `PulsingDot`: Animated presence indicator
- `HeroSurface`: Gradient container with shadow

### Screens Already Modernized
✅ **Home** (screens/home_screen.dart):
- Hero header uses `HeroSurface` with gradient
- Pickup code display: indigo subtle background
- Action tiles: gradient icon badges

✅ **Devices** (screens/devices_screen.dart):
- Summary card: `HeroSurface` with gradient + pulsing dot
- Device cards: gradient icon backgrounds

✅ **Files** (screens/my_files_screen.dart):
- File cards: gradient icon badges
- Pickup code chips: indigo subtle background

### Screens NOT Yet Modernized

#### Transfer Screen (screens/transfer_screen_new.dart)
❌ Issues:
- Flat AppBar (no gradient header)
- `ConnectionStatusPanel`: flat Container with border
- `StatusBanner`: flat Container with border
- `TransferProgressPanel`: basic Card, no gradient
- `DeviceTargetCard`: flat Card with border
- No hero section
- TabBar uses default Material style (not segmented control)

#### Transfer Widgets (widgets/transfer_widgets.dart)
❌ Issues:
- All Containers use borders instead of shadows
- No gradient backgrounds
- Hard-coded teal colors in some places
- Flat design throughout

#### Common Cards (widgets/common_cards.dart)
❌ `LoadingState`, `ErrorState`: basic implementations, no modern styling

#### App Shell (widgets/app_shell.dart)
✅ Uses theme's NavigationBar/NavigationRail (already styled)

#### Auth Screens (login_screen.dart, register_screen.dart, pickup_screen.dart)
❌ Not checked yet - likely need gradient headers, modern input styling

---

## Target Design (from Figma Windows references)

### Key Visual Patterns I CANNOT SEE (need confirmation):

1. **Sidebar/Navigation**
   - Current: Left sidebar ~240px, dark blue (#0C1E2E), cyan active indicator
   - Target: ???

2. **Top Bar**
   - Current: Search bar centered, icons right
   - Target: ???

3. **Hero Headers**
   - Current: `HeroSurface` with indigo→violet gradient
   - Target: Same gradient? Different colors? Different layout?

4. **Card Style**
   - Current: White cards, elevation 2, 12px radius, subtle shadow
   - Target: Same? Or different shadow/radius?

5. **Button Style**
   - Current: Cyan (#00BCD4) primary button
   - Target: Keep cyan or switch to indigo?

6. **Typography**
   - Current: Default system font, various weights
   - Target: Different font? Different sizes?

7. **Spacing**
   - Current: 16px card padding, 8-14px gaps
   - Target: More generous? Tighter?

8. **Transfer Screen Tabs**
   - Current: Material TabBar (underline indicator)
   - Target: Segmented control? Pill-shaped?

9. **Device Cards**
   - Current: Horizontal layout, gradient icon, status pill, pulsing dot
   - Target: Different layout? Different status display?

10. **File Cards**
    - Current: Horizontal, gradient icon, pickup code chip, metadata row
    - Target: Different layout? Different code display?

---

## Action Plan (BLOCKED - need visual confirmation)

I cannot proceed without seeing the Figma designs. The browser screenshots are not reaching me in this session.

**Options:**
1. **Restart Cline/VS Code** to reset the browser screenshot pipeline
2. **Export design specs manually**: For each of the 4 screens, provide:
   - Sidebar width, background color, active indicator style
   - Top bar layout (search position, icon sizes)
   - Hero header: gradient colors, height, content layout
   - Card style: shadow values, border radius, padding
   - Button colors: primary, secondary, ghost
   - Typography: font family, sizes for H1/H2/body/caption
   - Spacing: padding/margin values
   - Any unique components (segmented tabs, progress circles, etc.)
3. **Describe key differences**: Just tell me what's visually different from the current design (e.g., "sidebar is narrower", "buttons are more rounded", "cards have deeper shadows")

Once I can see or understand the target design, I'll update:
- Transfer screen + widgets
- Auth screens (login/register/pickup)
- Any remaining common widgets
- Run flutter analyze + build Windows to verify
