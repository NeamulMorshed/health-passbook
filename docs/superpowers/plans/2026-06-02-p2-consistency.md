# P2 Consistency Debt — Implementation Plan

> **For agentic workers:** executing-plans. Checkbox steps. Mechanical refactor; policy = safe/verifiable only (no compile or visual-regression risk).

**Goal:** Reduce design-system drift: dedupe the 3 greeting helpers, migrate exact-match raw hex to tokens, and migrate the unambiguous proven-twin Material icons to HugeIcons. Leave anything without an exact/proven mapping as-is (brand colors + decorative gradients + niche glyphs keep raw, with a clarifying comment where helpful).

**Scope correction:** The audit's "194 Material icons" was a grep artifact (matched `HugeIcons.*`). Real Material usage = 258 across 40 files / ~110 glyphs. Per user decision, P2 migrates only the **safe verifiable subset** (glyphs with a HugeIcons twin already proven in-codebase) + exact hex + greeting dedupe. Full 110-glyph migration is deferred to a dedicated mapping-table pass.

**Branch:** `feature/ux-audit-improvements`.

---

### Task 1: Shared greeting util

**Files:** Create `lib/core/utils/greeting.dart`; modify the 3 home/dashboard screens.

- [ ] Create util:
```dart
/// Time-of-day greeting, consistent across all portals.
String greetingForHour([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h >= 5 && h < 12) return 'Good Morning';
  if (h >= 12 && h < 17) return 'Good Afternoon';
  if (h >= 17 && h < 23) return 'Good Evening';
  return 'Good Night';
}
```
- [ ] In `patient/home/home_screen.dart`, `caregiver/home/caregiver_home_screen.dart`, `doctor/dashboard/doc_dashboard_screen.dart`: remove the local `String _greeting() {...}` and replace call sites `_greeting()` → `greetingForHour()`. Add the import. (Doctor gains the 4th "Good Night" branch — intentional consistency.)
- [ ] `flutter analyze` the 3 files → 0 errors. Commit.

---

### Task 2: Exact hex → tokens

**Files:** the screens containing the exact-match hex.

- [ ] Replace, repo-wide in `lib/screens`, ONLY these exact matches:
  - `const Color(0xFF7C3AED)` / `Color(0xFF7C3AED)` → `AppColors.inviteAccent`
  - `Color(0xFFD97706)` → `AppColors.warning`
  - `Color(0xFF3B82F6)` → `AppColors.info`
  - `Color(0xFFEFF6FF)` → `AppColors.infoLight`
  Do each file-by-file (confirm `AppColors` imported; it is in all screens via app_theme). Watch for `const` context — `AppColors.x` is a const, so `const Color(0xFF7C3AED)` inside a const expression stays valid.
- [ ] Google brand colors in `login_screen.dart` (`0xFF4285F4`, `0xFFEA4335`, `0xFFFBBC05`, `0xFF34A853`) — leave raw, add `// Google brand colors — intentionally not tokenized` comment above the block if not already present.
- [ ] Decorative gradient hex (`5B21B6`, `8B5CF6`, `6366F1`, `0EA5E9`, `4338CA`, `22C55E`, `15803D`, `B45309`, `0x0A000000`, `EF4444`) — leave (no exact token; out of safe scope).
- [ ] `flutter analyze` touched files → 0 errors. Commit.

---

### Task 3: Safe icon subset

**Policy:** Only convert `Icon(Icons.X, ...)` / `Icons.X` where X maps unambiguously to a HugeIcons glyph ALREADY used in the codebase. Convert the widget form too: `Icon(Icons.X, color: c, size: s)` → `HugeIcon(icon: HugeIcons.<twin>, color: c, size: s)` (HugeIcon requires color+size — supply sensible existing values from the call site; default `size: 20` if absent). Ensure `import 'package:hugeicons/hugeicons.dart';` present.

Proven map (twins confirmed in use elsewhere):
| Material | HugeIcons twin |
|----------|----------------|
| `close_rounded` | `strokeRoundedCancel01` |
| `check_rounded`, `done_rounded`, `done_all_rounded` | `strokeRoundedTick01` |
| `person_rounded`, `person_outline_rounded` | `strokeRoundedUser` |
| `delete_outline` | `strokeRoundedDelete01` |
| `chevron_right_rounded`, `arrow_forward_ios_rounded` | `strokeRoundedArrowRight01` |
| `calendar_today_rounded`, `calendar_month_rounded`, `calendar_month_outlined` | `strokeRoundedCalendar01` |
| `add_rounded` | `strokeRoundedPlusSign` |
| `send_rounded` | `strokeRoundedSent` |

- [ ] Migrate the above glyphs across `lib/screens`, one file at a time. Skip any site where the surrounding widget isn't a simple `Icon(...)` (e.g. `IconData` passed as a variable, `IconButton(icon: Icon(...))` is fine to convert). When unsure → leave it.
- [ ] Leave ALL other Material glyphs (error/empty-state icons, food/fitness/medical icons, etc.) as-is — out of safe scope.
- [ ] `flutter analyze` after each file. Commit in 1–2 batches.

---

### Task 4: Verify + docs

- [ ] `flutter analyze` → 0 errors, 0 warnings (≤32 info). `flutter test` → all pass.
- [ ] Note remaining Material-icon count (for the deferred full pass) + update `.claude/UPDATES.md`. Commit.

## Self-Review
Greeting (T1), exact hex (T2), safe icons (T3), verify (T4). No placeholders. Twin names in T3 are all confirmed present elsewhere in `lib` (proven to compile). Non-exact hex + niche glyphs explicitly out of scope.
