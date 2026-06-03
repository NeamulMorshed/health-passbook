# ADR-004 — Firestore Security Rules

#adr #security

**Date:** 2026-05, fixed 2026-05-24  
**Status:** ✅ Implemented (v2.11.0+35)

## Fixes Applied

| Vuln | Fix |
|------|-----|
| S-01 | `allow list` now requires patientId/doctorId/caregiverHasPatient match |
| S-02 | users `allow update` blocks `userType` field via `!affectedKeys().hasAny(['userType'])` |
| S-03 | medicines `allow create` requires `doctorHasPatient(patientId)` |
| S-04 | prescriptions `allow create` requires `doctorHasPatient(request.resource.data.patientId)` |

## Note
`doctorHasPatient()` function was already in rules — only call sites needed adding.

## Remaining at Time of ADR
S-05 (email case), S-07 (O(n) cloud function) — both subsequently fixed in Phase 3.

→ [[Security Overview]]  
→ [[ADR Index]]
