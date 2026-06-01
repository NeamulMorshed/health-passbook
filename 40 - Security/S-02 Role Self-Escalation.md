# S-02 — Role Self-Escalation

#security

**Status:** ✅ Fixed (v2.11.0+35, ADR-004)  
**File:** `vitalpath_flutter/firestore.rules`  
**Severity:** Critical

## Problem
User could write `userType` field on their own document — self-escalating from patient to doctor, gaining access to all doctor-only routes and data.

## Fix Applied
Split `users/{uid}` rule:
- `allow create` — unrestricted for owner (signup needs to write userType once)
- `allow update` — blocks `userType` via `!affectedKeys().hasAny(['userType'])`

## Related
→ [[Security Overview]]  
→ [[80 - Decisions/ADR-004 Firestore Security Rules]]
