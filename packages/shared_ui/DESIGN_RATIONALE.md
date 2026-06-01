# Modern Glassmorphism Refresh — Design Rationale

## Table of Contents
1. [Aesthetic Direction](#1-aesthetic-direction)
2. [Aurora Mesh Background](#2-aurora-mesh-background)
3. [Animation Philosophy](#3-animation-philosophy)
4. [Colour Palette Additions](#4-colour-palette-additions)
5. [Component Design Decisions](#5-component-design-decisions)
6. [Typography Refinements](#6-typography-refinements)
7. [Accessibility & Reduced Motion](#7-accessibility--reduced-motion)
8. [Performance Considerations](#8-performance-considerations)
9. [Migration Guide](#9-migration-guide)

---

## 1. Aesthetic Direction

The original "Midnight Zinc" theme established a solid dark foundation (zinc-900/950, violet-500 accent). The refresh keeps that foundation but adds **atmosphere, playfulness, and micro-motion** — three qualities that signal "premium" to the Indonesian Gen-Z audience.

**Why this works for the superapp:**
- **Trade module** — the cyan accent (`#06B6D4`) signals liquidity, uptrends, "active market". Paired with the dark canvas it feels like a Bloomberg terminal redesigned for mobile.
- **Fashion module** — the magenta/pink accent (`#EC4899`) brings energy, trendiness. The aurora background adds a runway-show glow.
- **Scholarship module** — the violet anchor (`#8B5CF6`) conveys ambition, intellect. Number counters with decelerating ease feel like achievements counting up.

The design walks a line between **maximalist glow** (aurora, shimmer) and **restrained UI** (cards stay flat, text stays sharp). This tension — dark/minimal chrome with a colourful, living background — is the "glassmorphism 2.0" aesthetic.

---

## 2. Aurora Mesh Background

**Replaces:** The old `GradientBackground` (2 static circles, fixed positions).

**New approach:** 4 orbs (violet, pink, cyan, soft violet) that drift organically using sine/cosine functions at different frequencies:

| Orb  | Colour       | Base Position | Frequency | Size  | Alpha |
|------|-------------|---------------|-----------|-------|-------|
| 1    | Violet      | Top-left      | Slow      | 320px | 20%   |
| 2    | Pink        | Bottom-right  | Medium    | 360px | 13%   |
| 3    | Cyan        | Centre-right  | Fast      | 280px | 13%   |
| 4    | Soft violet | Bottom-left   | Cross     | 250px | 15%   |

**Why 4 orbs?** Three would feel too symmetrical; five adds perceptible visual noise. Four creates a dynamic, asymmetric composition that never visually repeats during the 12-second cycle because each orb uses different frequency ratios (0.7×, 0.5×, 0.3×, 0.9× — all co-prime-ish).

**Why these colours?** Violet anchors to the existing accent; pink adds warmth; cyan adds cool contrast. Together they span the visible spectrum of the brand without feeling muddy.

**Why 90 px blur?** At this sigma the orbs become pure atmospheric colour fields — you can't tell where one orb ends and another begins. Lower values (30-60 px) look like "blurry circles" which is less premium.

**Intensity & Speed controls:** `intensity` (0.0–1.5) scales orb sizes and movement ranges. `speed` (default 1.0) scales the 12 s cycle. These let designers tone down the effect for text-heavy screens.

**Static fallback:** When `MediaQuery.disableAnimations` is true, the orbs are skipped entirely. The BackdropFilter with 90 px blur remains on the canvas-colour background, creating a subtle static depth.

---

## 3. Animation Philosophy

### Timing Constants (`AppMotion`)

| Token     | Value   | Use case                                    |
|-----------|---------|---------------------------------------------|
| `fast`    | 150 ms  | Button press, hover glow, toggle states     |
| `normal`  | 250 ms  | Card scale, chip selection, pulse dots      |
| `slow`    | 400 ms  | Page transitions, staggered list items       |
| `page`    | 350 ms  | Shared-axis transitions                      |

**Why these values?** 
- 150 ms is just below the 200 ms threshold where UI feels "laggy" — it's instantaneous but visible.
- 350-400 ms is the sweet spot for navigation transitions: fast enough to feel responsive, slow enough for the brain to register spatial change.
- 700-800 ms for NumberCounter gives a satisfying "counting up" without impatience.
- 1200-1600 ms for repeating animations (shimmer, pulse) keeps them hypnotic but not distracting.

### Curves

| Token         | Curve               | Use                                 |
|---------------|---------------------|-------------------------------------|
| `emphasized`  | `easeInOutCubic`    | Shared transitions, tab switches    |
| `standard`    | `easeOutCubic`      | Enter animations, press scale       |
| `decelerate`  | `easeOutQuart`      | Counter count-up, dismiss           |
| `spring`      | `easeOutBack`       | Playful moments (not used heavily)  |

**Why `easeOutCubic` as standard?** It's snappier than `easeOut` (sine) — 70% of the animation completes in the first 40% of duration — which makes the UI feel fast and responsive while still being smooth.

### Micro-interactions

Every tappable surface has a **scale-down on press** (0.96–0.97). This is the single highest-ROI micro-interaction: it provides immediate tactile feedback that the press registered. The `easeOutCubic` curve means the card "snaps back" with a satisfying bounce-light feel.

Loading states use a **pulse** (±8% scale oscillation) rather than a spinner where possible. The pulse keeps the button/area "alive" while loading, preventing the visual dead-zone that spinners create.

### Staggering

`StaggeredListItem` uses a delay of `index × 50 ms`. At this rate, item 0 enters at 0 ms, item 1 at 50 ms, item 2 at 100 ms — creating a cascading effect that feels natural (like a wave) rather than robotic. The 400 ms duration means a list of 8 items finishes animating in ~750 ms, well within the user's attention span.

---

## 4. Colour Palette Additions

### New module-specific accents

| Token          | Hex       | Replaces?          | Module          |
|----------------|-----------|--------------------|-----------------|
| `accentCyan`   | `#06B6D4` | Was `success=#34D399` (emerald) | Trade / positive metrics |
| `accentOrange` | `#F97316` | Was `warning=#F59E0B` (amber)   | Warnings, risk  |
| `accentPink`   | `#EC4899` | New                | Fashion accent  |

**Why cyan over emerald for success?** Emerald (`#34D399`) is pleasant but leans mint — it clashes with the violet-zinc palette (mint + violet + zinc = messy). Cyan (`#06B6D4`) is cooler and harmonises: on the colour wheel, cyan is adjacent to blue/violet, creating a natural gradient relationship.

**Why orange over amber for warnings?** Amber (`#F59E0B`) is close to yellow — low contrast on dark backgrounds and reads as "caution" rather than "warning". Orange (`#F97316`) has higher contrast, more urgency, and pairs dramatically with the dark canvas.

**Why pink for fashion?** Violet anchors the brand. Pink is the analogous neighbour on the colour wheel. Using pink for the fashion module creates visual family without being the same colour as the main brand. It's also culturally resonant — pink is popular in Indonesian Gen-Z fashion.

### Aurora mesh alphas

The alpha values (`0x33` = ~20%, `0x22` = ~13%) are intentionally low. The orbs are meant to be felt rather than seen — atmospheric colour that you'd struggle to screenshot. This is the essence of glassmorphism: presence without prominence.

---

## 5. Component Design Decisions

### GlassCard Variants

The default `GlassCard()` constructor keeps the original flat look for backward compatibility. Three new named constructors add depth:

- **`.elevated`** — Uses `elevation=3` which maps to `AppShadows.md + AppShadows.lg` (16 px + 24 px blur). The `borderGlow` adds a hover-detectable violet border on desktop via `MouseRegion`. On mobile, the press animation (scale 0.97) serves as the interaction cue.

- **`.gradient`** — Accepts a custom `Gradient`. Designed for feature cards that need visual hierarchy (e.g., "Promo Banner", "Featured Scholarship"). No shadow (shadows + gradients = visual clutter).

- **`.aurora`** — Auto-derives a gradient from the mesh palette (violet→pink→cyan). When `auroraColors` is provided, uses that list instead. The subtle elevation (`elevation=1`) gives just enough depth to separate from the background without overpowering.

### SleekButton (replaces GlassButton)

`GlassButton` is preserved for backward compatibility. `SleekButton` adds:

1. **Gradient variant** — Violet→pink diagonal gradient via `SleekButton.gradient()` constructor. The gradient is rendered as a `LinearGradient` with `begin: Alignment.centerLeft, end: Alignment.centerRight`. This avoids the "hard edge" problem of vertical gradients on wide buttons.

2. **Loading pulse** — When loading, the button scales ±8% at 1.2 s intervals using `easeInOutSine`. This is more engaging than a static spinner. The spinner is still shown inside the button (18 px `CircularProgressIndicator`).

3. **Icon-only mode** — When `iconOnly: true`, the button becomes circular (height = width) with no padding — ideal for FABs, floating actions, and nav items. The gradient variant works beautifully for icon-only buttons.

4. **Press animation** — Scale 0.96 + the existing brightness composition (via the button's existing AnimatedContainer with colour transition). Two layers of feedback: shape change + colour change.

### SleekChip

The chip uses `borderRadius: 16` (fully pill-shaped) for a friendlier, more modern silhouette than the original `GlassBadge` (which uses `borderRadius: 6`). 

The remove (×) icon is a `GestureDetector`-wrapped `Icons.close_rounded` — it's positioned inside the chip's padding with a 6 px gap. The hit area is implicitly the icon's 14 px size, which is adequate for the standard touch target of 44 px because the chip itself is tappable.

Selection is handled via `onSelected` callback. When selected, the chip gets a violet-tinted background and border — visually linking to the brand accent.

### PulseDot

The dot uses a 1.4 s `easeInOutSine` pulse animating both opacity (0.4→1.0) and scale (0.85→1.0). The multi-layered glow via `BoxShadow` with `blurRadius: size * 0.6` creates a soft halo effect.

**Colour guidance:** Green for "market open / live", violet for "broadcasting", amber for "attention needed". The dot is small (8 px default) — intentionally subtle, not a badge.

---

## 6. Typography Refinements

The existing `.SF Pro Display` font family is kept (it's the system font on iOS and widely recognised as premium). The key change is **tighter letter-spacing on display text**:

| Style     | Before | After | Why                                       |
|-----------|--------|-------|-------------------------------------------|
| `display` | -0.8   | -1.2  | At 34 px, tighter spacing looks editorial |
| `headline`| -0.4   | -0.6  | More refined at 22 px                     |
| `title`   | -0.1   | -0.2  | Subtle tightening for hierarchy           |
| `label`   | +0.8   | +0.8  | Unchanged — caps tracking                 |

**Implementation note:** These changes should be applied in `app_theme.dart` by modifying `AppTextStyles` constants. The new values are not in a separate file to avoid fragmentation.

### Shadow Levels

`AppShadows` defines 5 levels (xs → xl) ranging from 4 px to 48 px blur. These are intentionally conservative — on a dark theme, shadows should be felt (depth) rather than seen (visible dark blobs). The opacity ramps from `0x08` (~3%) to `0x18` (~9%).

---

## 7. Accessibility & Reduced Motion

Every animated widget checks `MediaQuery.of(context).disableAnimations`:

| Widget                    | Behaviour when disabled                               |
|---------------------------|-------------------------------------------------------|
| `AuroraMeshBackground`    | Orbs omitted entirely; static blur layer remains     |
| `SleekButton`             | Scale animations skipped; loading spinner still shown |
| `PulseDot`                | Static circle, no opacity/scale animation            |
| `ShimmerPlaceholder`      | Single-colour dark placeholder, no gradient sweep    |
| `NumberCounter`           | Immediate display of target value, no count-up       |
| `StaggeredListItem`       | Child shown directly without fade/slide              |
| `GlassCard`               | Press scale skipped; onTap still fires               |
| `SharedAxis*Transition`   | Child shown directly without transition               |

**Colour contrast:** All new components inherit from the existing palette, which has a minimum contrast ratio of 7:1 between ink (#FAFAFA) and canvas (#09090B). The new accent colours (cyan, orange, pink) are used for decorative/status purposes only — never for body text.

---

## 8. Performance Considerations

- **`BackdropFilter` is used only in `AuroraMeshBackground`** — a single instance per screen, positioned as the root background. This is acceptable because: (a) it's rendered once, not in a scrolling list; (b) the 90 px blur is GPU-accelerated on modern devices; (c) when animations are disabled, the blur is still present but without the orbs animating.

- **No `BackdropFilter` in cards or list items** — The `GlassCard` variants use plain `BoxDecoration` with colour and shadow. This keeps scrolling smooth even on mid-range Android devices common in the Indonesian market.

- **`AnimatedBuilder` is used over `setState` for animation frames** — This avoids unnecessary widget subtree rebuilds. Only the animated layer rebuilds; the child subtree is passed as a `child` parameter and preserved.

- **Orb position calculations use `math.sin`/`math.cos`** — These are computed per frame for 4 orbs (≈ 8 trig calls). On any modern device this is negligible (< 0.01 ms per frame).

- **`IntTween` for NumberCounter** — Uses integer easing which avoids the visual jitter of floating-point rounding. The `easeOutQuart` curve creates a satisfying deceleration.

---

## 9. Migration Guide

### New imports

```dart
// In shared_ui.dart — add these exports:
export 'widgets/aurora.dart';
export 'widgets/sleek_button.dart';
export 'widgets/sleek_chips.dart';
export 'widgets/animation_widgets.dart';
export 'widgets/motion.dart';
export 'widgets/sleek_cards.dart';

// Note: GlassCard is hidden from glass.dart to avoid conflict.
// The enhanced GlassCard from sleek_cards.dart has all original
// parameters plus .elevated, .gradient, .aurora constructors.
```

### Gradual adoption (no breaking changes)

| Old widget        | Status         | New recommendation            |
|-------------------|----------------|-------------------------------|
| `GradientBackground` | Still works  | Replace with `AuroraMeshBackground` for animated screens |
| `GlassButton`        | Still works  | Replace with `SleekButton` for new code |
| `GlassCard()`        | Still works (from sleek_cards.dart) | Use `.elevated` for data cards, `.gradient` for promo |
| `SleekPageTransition` | Still works | Add `PageTransition.horizontal` / `.vertical` for new routes |
| `GlassBadge`         | Still works  | Consider `SleekChip` for interactive chips |

### One-time app_theme.dart additions

Merge these into `AppColors` in `app_theme.dart`:

```dart
// Module-specific accents
static const accentCyan   = Color(0xFF06B6D4);
static const accentOrange = Color(0xFFF97316);
static const accentPink   = Color(0xFFEC4899);

// Aurora mesh
static const auroraViolet = Color(0x338B5CF6);
static const auroraPink   = Color(0x22EC4899);
static const auroraCyan   = Color(0x2206B6D4);
```

Update `AppTextStyles` with tighter letter-spacing:

```dart
static final display = _base.copyWith(
  fontSize: 34, fontWeight: FontWeight.w700,
  letterSpacing: -1.2, height: 1.1,
);
static final headline = _base.copyWith(
  fontSize: 22, fontWeight: FontWeight.w700,
  letterSpacing: -0.6, height: 1.2,
);
static final title = _base.copyWith(
  fontSize: 15, fontWeight: FontWeight.w600,
  letterSpacing: -0.2, height: 1.3,
);
```

---

## File Map

```
packages/shared_ui/lib/
├── theme/
│   └── app_theme.dart          ← Add new accent colours + tighter letter-spacing
├── widgets/
│   ├── glass.dart              ← Unchanged (backward compat)
│   ├── aurora.dart             ← NEW: MeshOrb, AuroraMeshBackground, AppAccent
│   ├── sleek_button.dart       ← NEW: SleekButton (replaces GlassButton)
│   ├── sleek_chips.dart        ← NEW: SleekChip, PulseDot
│   ├── animation_widgets.dart  ← NEW: ShimmerPlaceholder, NumberCounter, StaggeredListItem
│   ├── motion.dart             ← NEW: AppMotion, AppShadows, SharedAxis*Transition, PageTransition
│   └── sleek_cards.dart        ← NEW: GlassCard with .elevated/.gradient/.aurora
├── shared_ui.dart              ← Updated exports
└── DESIGN_RATIONALE.md         ← This file
```

---

*Designed for the Indonesian Gen-Z superapp — trade, fashion, and scholarship.*  
*June 2026*
