---
name: omra-design-check
description: >
  Design system compliance checker for Omra. After any UI edit, verifies the changed
  file follows .claude/DESIGN_SYSTEM.md rules: AppColors tokens (no raw hex), correct
  BentoCard widgets, HugeIcons (not Material icons), Open Sans font via GoogleFonts,
  and standard spacing values.
  Invoke: /omra-design-check [file-path]  e.g. /omra-design-check lib/screens/patient/home/home_screen.dart
---

Check the given Dart file for design system violations. Read `.claude/DESIGN_SYSTEM.md` for the rules.

## Checks to Run

### 1. Color Violations
Scan for any of these patterns — each is a violation:
- `Color(0x` — raw hex color
- `Color.fromRGBO(` — raw RGB color
- `Colors.red`, `Colors.blue`, `Colors.green`, etc. — Material named colors (not in AppColors)
- Exception: `Colors.white`, `Colors.black`, `Colors.transparent` are acceptable when used as overlay/alpha values

For each violation: `[file:line] COLOR: Color(0xFF...) → AppColors.[nearest token]`

### 2. Widget Violations
- `Card(` without using `BentoCard` — flag as potential inconsistency (explain intended BentoCard equivalent)
- `ListTile(` in settings contexts — should be `BentoSettingsTile`
- `Row(children: [Expanded(...), SizedBox(...), Expanded(...)])` pattern — should be `BentoRow`

### 3. Icon Violations
Scan for `Icons.` (Material icon namespace):
- For each: `[file:line] ICON: Icons.medicine → HugeIcons.strokeRoundedMedicine01`
- Note: if HugeIcons has no equivalent, a comment `// no HugeIcons equivalent` must be present

### 4. Font Violations
- `TextStyle(fontFamily: 'OpenSans')` or any raw fontFamily string — should use `GoogleFonts.openSans(...)`
- `Text(...)` without a style that references `AppColors` for color — flag if using raw `Colors.*` in text

### 5. Spacing Violations
Flag `EdgeInsets.all(` values not in `{4, 8, 12, 16, 20, 24}` as potentially non-standard (ask to confirm intent).

## Output Format
One line per violation: `[file:line] [CHECK-TYPE]: [what was found] → [correct form]`

## Example Output
```
lib/screens/patient/home/home_screen.dart:342  COLOR: Color(0xFFF59E0B) → AppColors.caregiver
lib/screens/patient/home/home_screen.dart:567  ICON: Icons.check_circle → HugeIcons.strokeRoundedCheckmarkCircle01
lib/screens/patient/home/home_screen.dart:891  FONT: TextStyle(fontFamily: 'OpenSans') → GoogleFonts.openSans(...)
─────────────────────────────────────────────
3 violations found.
```

If clean:
```
lib/screens/patient/home/home_screen.dart — Design system CLEAN ✓
```
