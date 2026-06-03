# ADR Index

#architecture #decisions

> Source of truth: `.claude/DECISIONS.md`  
> This note = quick-reference index + links

---

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| ADR-001 | Client-Side Sorting (no orderBy + where) | ✅ Implemented v2.11.0+34 | 2026-05 |
| ADR-002 | "Family Member" Terminology (not Caregiver) | ✅ Implemented v2.11.0+33 | 2026-05 |
| ADR-003 | Defensive Stream Pattern (try-catch in fromMap) | ✅ Implemented v2.11.0+34 | 2026-05 |
| ADR-004 | Firestore Security Rules — Critical Fixes | ✅ Implemented v2.11.0+35 | 2026-05 |
| ADR-005 | No dependency_overrides in pubspec.yaml | ✅ Permanent policy | 2026-05 |
| ADR-006 | Workflow Infrastructure (Claude Code Setup) | ✅ Implemented v2.11.0+35 | 2026-05-24 |
| ADR-007 | UX-1 Health Profile Onboarding Gap Closure | ✅ Implemented v2.11.0+35 | 2026-05-24 |
| ADR-008 | UX-2 Appointment-Confirmation Notification Loop | ✅ Implemented | 2026-05-24 |
| ADR-009 | UX-3 Prescription Confirmation Dialog | ✅ Implemented v2.11.0+35 | 2026-05-24 |
| ADR-010 | UX-4 Permission Lock UX: Actionable "Request Access" | ✅ Implemented v2.11.0+35 | 2026-05-24 |
| ADR-011 | T-02 Caregiver Firestore Permission Enforcement | ✅ Implemented v2.11.0+35 | 2026-05-24 |
| ADR-012 | UX-8 Vitals Trending Charts | ✅ Implemented v2.11.0+35 | 2026-05-24 |
| ADR-013 | UX-9 Nudge Follow-up Indicator | ✅ Implemented v2.11.0+35 | 2026-05-26 |
| ADR-014 | UX-10 Doctor "Needs Attention" Dashboard Section | ✅ Implemented v2.11.0+35 | 2026-05-26 |
| ADR-015 | UX-11 Appointment Reminders | ✅ Implemented v2.11.0+35 ⚠ deploy pending | 2026-05-26 |

---

## Key Non-Negotiable Rules (from ADRs)

1. **Never** `.orderBy()` + `.where()` on same Firestore query → sort client-side (ADR-001)
2. **Never** `dependency_overrides` in pubspec.yaml (ADR-005)
3. **Always** `try-catch` in `fromMap()` inside streams (ADR-003)
4. **Always** use `(map['field'] as num?)?.toInt()` for numeric Firestore fields (ADR-003)
5. **Always** "Family Member" in UI text — never "Caregiver" (ADR-002)
6. **Always** `AppColors.tokenName` — never raw hex values (CLAUDE.md)
7. **Always** `HugeIcons.strokeRounded*` — no Material Icons where HugeIcon exists (CLAUDE.md)

---

## ADR Notes
→ [[ADR-001 Client-Side Sorting]]
→ [[ADR-004 Firestore Security Rules]]
→ [[ADR-011 Caregiver Permission Enforcement]]
→ [[ADR-013 Nudge Follow-up]]
→ [[ADR-014 Doctor Needs Attention]]
→ [[ADR-015 Appointment Reminders]]
