# Design System

#design #reference

> Source of truth: `.claude/DESIGN_SYSTEM.md`  
> This note = quick-access summary. Read full file before any UI/widget/color edit.

---

## Colors (AppColors tokens)

> File: `lib/core/theme/app_theme.dart`  
> Rule: **ALWAYS** use token — never raw hex

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | #0F9D77 | Patient portal, primary actions |
| `caregiver` | #F59E0B | Family member portal, amber accents |
| `destructive` | — | Errors, critical alerts |
| `info` | — | Info badges |
| `warning` | — | Warning badges |
| `success` | — | Success states |
| `textSecondary` | #4B5563 | Secondary text (7.34:1 contrast, WCAG AA) |
| `textTertiary` | #6B7280 | Tertiary text (4.84:1 contrast, WCAG AA) |

> Note: textSecondary bumped from #6B7280 → #4B5563 and textTertiary bumped from #9CA3AF → #6B7280 for WCAG AA compliance (Phase 9b)

---

## Bento Widget System

File: `lib/core/widgets/bento_card.dart`

| Widget | Purpose |
|--------|---------|
| `BentoCard` | Standard card container |
| `BentoStatCard` | Stat display with label + value |
| `BentoRow` | Side-by-side two-card layout |
| `BentoFeaturedCard` | Prominent featured content card |
| `BentoSettingsTile` | Settings list item |
| `BentoSectionHeader` | Section label header |

---

## Icons

- **Rule:** Use `HugeIcons.strokeRounded*` variant
- **Package:** HugeIcons ^1.1.4
- **Never:** Material Icons where HugeIcon equivalent exists

---

## Typography

- **Font:** Open Sans (google_fonts ^6.2.1)
- All text styles defined in `AppTheme`

---

## Tap Targets

- Minimum 44dp on all interactive elements (enforced Phase 9c)
- Applies especially to icon-only buttons (HP info, dismiss-close on awareness cards)

---

## Spacing

→ Read `.claude/DESIGN_SYSTEM.md` for full spacing scale
