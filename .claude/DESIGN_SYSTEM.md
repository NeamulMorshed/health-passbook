# Omra — Design System Reference
<!-- Source: lib/core/theme/app_theme.dart + lib/core/widgets/bento_card.dart -->
<!-- Claude: Read the relevant section before any UI edit. Never use raw hex. Never use wrong widgets. -->

---

## AppColors Token Table
<!-- Source: lib/core/theme/app_theme.dart — AppColors class -->
<!-- RULE: Always use AppColors.tokenName. Never use Color(0xFF...) or Colors.* directly. -->

### Brand / Primary
| Token | Hex | Usage |
|-------|-----|-------|
| `AppColors.primary` | `#0F9D77` | All portals — CTAs, active nav, primary buttons, rings |
| `AppColors.primaryLight` | `#3DB896` | Lighter tint of primary for hover/pressed states |
| `AppColors.primaryDark` | `#0B7A5E` | Darker shade for emphasis |
| `AppColors.primaryTint` | `#E8F5F1` | Icon background containers in stat cards |
| `AppColors.primaryXLight` | `#F2FAF7` | Very light fill backgrounds (featured cards) |

### Page & Surface
| Token | Hex | Usage |
|-------|-----|-------|
| `AppColors.pageBackground` | `#F2F2F0` | Scaffold background — all screens |
| `AppColors.surface` | `#FFFFFF` | Card backgrounds, sheet backgrounds |
| `AppColors.surfaceSubtle` | `#F7F7F5` | Input fields fill, settings tile icons |

### Text
| Token | Hex | Usage |
|-------|-----|-------|
| `AppColors.textPrimary` | `#111827` | Body text, headings, labels |
| `AppColors.textSecondary` | `#6B7280` | Subtitles, captions, secondary labels |
| `AppColors.textTertiary` | `#9CA3AF` | Placeholder text, inactive nav labels |
| `AppColors.textOnPrimary` | `#FFFFFF` | Text on primary-colored buttons |

### Borders
| Token | Hex | Usage |
|-------|-----|-------|
| `AppColors.border` | `#E5E5E3` | Card borders (0.5px), dividers |
| `AppColors.borderStrong` | `#D1D5DB` | Input borders, stronger separators |

### Semantic
| Token | Hex | Usage |
|-------|-----|-------|
| `AppColors.success` | `#16A34A` | Taken / completed / positive states |
| `AppColors.successLight` | `#DCFCE7` | Success background fills |
| `AppColors.warning` | `#D97706` | Due / pending / caution states |
| `AppColors.warningLight` | `#FEF3C7` | Warning background fills |
| `AppColors.destructive` | `#DC2626` | Errors, delete actions, missed states |
| `AppColors.destructiveLight` | `#FEE2E2` | Error background fills |
| `AppColors.info` | `#3B82F6` | Informational states, links |
| `AppColors.infoLight` | `#EFF6FF` | Info background fills |

### Portal Accent Colors
| Token | Hex | Portal | Usage |
|-------|-----|--------|-------|
| `AppColors.caregiver` | `#F59E0B` | Family Member | Amber accent — stat values, icons, highlights |
| `AppColors.caregiverLight` | `#FEF3C7` | Family Member | Amber background fills |
| `AppColors.inviteAccent` | `#7C3AED` | Invite flows | Purple — invite banners, care circle |
| `AppColors.inviteAccentLight` | `#EDE9FE` | Invite flows | Purple background fills |

### Legacy Aliases (do not use these in new code — they map to the real tokens above)
| Alias | Maps To |
|-------|---------|
| `AppColors.background` | `AppColors.pageBackground` |
| `AppColors.muted` | `AppColors.surfaceSubtle` |
| `AppColors.mutedForeground` | `AppColors.textSecondary` |
| `AppColors.foreground` | `AppColors.textPrimary` |
| `AppColors.cardForeground` | `AppColors.textPrimary` |
| `AppColors.doctorPrimary` | `AppColors.primary` |
| `AppColors.doctorLight` | `AppColors.primaryTint` |

---

## Widget Catalog
<!-- Source: lib/core/widgets/bento_card.dart — 6 widgets -->

### BentoCard (base card)
```dart
BentoCard(
  child: ...,
  padding: const EdgeInsets.all(16), // default
  color: AppColors.surface,          // default
  onTap: () {},                      // optional — makes card tappable with InkWell
  borderRadius: 16,                  // default
  height: 120,                       // optional fixed height
)
```
- Use for: any standard content container
- Background: `AppColors.surface` (#FFFFFF) with `AppColors.border` (0.5px) stroke
- Border radius: 16px
- Do NOT nest BentoCards inside BentoCards

### BentoStatCard (single metric)
```dart
BentoStatCard(
  label: 'taken today',
  value: '3',
  unit: '/5',                        // optional suffix
  icon: HugeIcon(icon: HugeIcons.strokeRoundedMedicine01, color: AppColors.primary, size: 18),
  iconBgColor: AppColors.primaryTint, // default
  iconColor: AppColors.primary,      // default
  onTap: () {},                      // optional
  bottomWidget: LinearProgressIndicator(...), // optional
)
```
- Icon container: 36×36px, borderRadius 10px
- Value: OpenSans 22px w700 `AppColors.textPrimary`
- Label: OpenSans 12px `AppColors.textSecondary`

### BentoRow (two equal cards side by side)
```dart
BentoRow(
  left: BentoStatCard(...),
  right: BentoStatCard(...),
  gap: 12, // default
)
```
- Use for: exactly TWO side-by-side equal-width cards
- Gap: 12px between cards

### BentoFeaturedCard (icon + title + subtitle + tags)
```dart
BentoFeaturedCard(
  title: 'AI Health Insights',
  subtitle: 'Personalised recommendations',
  icon: HugeIcon(...),
  tags: ['Nutrition', 'Activity'],   // optional
  bgColor: AppColors.primaryXLight,  // default
  onTap: () {},
)
```
- Icon container: 44×44px, white 60% opacity bg, borderRadius 12px
- Tags: pill-shaped chips, white 70% bg

### BentoSettingsTile (settings list item)
```dart
BentoSettingsTile(
  icon: HugeIcon(icon: HugeIcons.strokeRoundedUser, color: AppColors.primary, size: 20),
  title: 'Personal Information',
  subtitle: 'Name, DOB, blood type', // optional
  onTap: () {},
  trailing: Switch(...),             // optional — defaults to arrow icon
  showDivider: true,                 // default
)
```
- Icon container: 36×36px, `AppColors.surfaceSubtle` bg, borderRadius 10px
- Default trailing: `HugeIcons.strokeRoundedArrowRight01` in `AppColors.textTertiary`
- Divider: indented 64px from left

### BentoSectionHeader (section title + optional action link)
```dart
BentoSectionHeader(
  title: 'Your Medicines',
  action: 'See all',   // optional
  onAction: () {},     // optional
)
```
- Title: OpenSans 15px w600 `AppColors.textPrimary`
- Action: OpenSans 13px w500 `AppColors.textSecondary`

---

## Icon Rules
- **Always** use `HugeIcons.strokeRounded*` variants from the `hugeicons` package
- **Sizes:** 18px in stat card containers · 20px inline/settings · 22px AppBar · 24px standalone nav
- **Only** use `Icons.*` (Material) if `hugeicons` has no equivalent — must add a comment explaining why
- Import: `import 'package:hugeicons/hugeicons.dart';`
- Usage: `HugeIcon(icon: HugeIcons.strokeRoundedMedicine01, color: AppColors.primary, size: 20)`

---

## Typography Scale
<!-- Source: lib/core/theme/app_theme.dart — AppTheme.lightTheme textTheme -->
<!-- Font: Open Sans via google_fonts — GoogleFonts.openSans(...) -->

| Style | Size | Weight | Color Token | Use For |
|-------|------|--------|-------------|---------|
| displaySmall | 22px | w700 | textPrimary | Stat values in BentoStatCard |
| headlineMedium | 18px | w700 | textPrimary | Screen titles, section big headers |
| headlineSmall | 17px | w600 | textPrimary | AppBar titles |
| titleLarge | 16px | w600 | textPrimary | Card titles, primary labels |
| titleMedium | 15px | w600 | textPrimary | BentoSectionHeader title |
| bodyLarge | 16px | w400 | textPrimary | Body text, list items |
| bodyMedium | 14px | w400 | textPrimary | Standard body text |
| bodySmall | 13px | w400 | textSecondary | Secondary descriptions |
| labelLarge | 14px | w600 | textPrimary | Button labels |
| labelSmall | 12px | w500 | textTertiary | Tags, captions |

**Rule:** Use `GoogleFonts.openSans(fontSize: X, fontWeight: FontWeight.wXXX, color: AppColors.tokenName)` or theme tokens. Never `TextStyle(fontFamily: 'OpenSans')` directly.

---

## Spacing & Layout Conventions
| Context | Value |
|---------|-------|
| BentoCard internal padding | 16px all sides |
| Card-to-card vertical gap | 12px |
| Section-to-section gap | 24px |
| Icon container → text (horizontal) | 12–14px SizedBox |
| Icon container → text (vertical, below icon) | 12px SizedBox |
| Screen horizontal padding | 16px (via SliverPadding or Padding) |
| Bottom nav height | 72px |
| Button minimum height | 52px |
| Input field border radius | 12px |
| Card border radius | 16px |
| Icon container border radius | 10px |

---

## Buttons
| Type | Widget | Min Size | Shape | Color |
|------|--------|----------|-------|-------|
| Primary action | `ElevatedButton` | full-width × 52px | pill (r=100) | `AppColors.primary` bg, white text |
| Secondary action | `OutlinedButton` | full-width × 52px | pill (r=100) | `AppColors.primary` border + text |
| Text/link | `TextButton` | auto | none | `AppColors.primary` text |

---

## Navigation Structure
| Portal | Bottom Nav Tabs | Active Color | Inactive Color |
|--------|----------------|-------------|----------------|
| Patient | Home / Care / Appointments / Profile | `AppColors.primary` | `AppColors.textTertiary` |
| Doctor | Dashboard / Patients / Appointments / Profile | `AppColors.primary` | `AppColors.textTertiary` |
| Family Member | Home / My Family / Profile | `AppColors.primary` | `AppColors.textTertiary` |

---

## Bottom Sheets & Dialogs
- Bottom sheet background: `AppColors.surface`, top border radius 20px
- AlertDialog for: destructive actions (delete, cancel appointment) — red confirm button
- Bottom sheet for: confirming new records (prescription, appointment slot)
- Full screen for: new connections (invite, accept invite)
