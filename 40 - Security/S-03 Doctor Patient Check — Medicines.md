# S-03 — Doctor Patient Check (Medicines)

#security

**Status:** ✅ Fixed (v2.11.0+35, ADR-004)  
**File:** `vitalpath_flutter/firestore.rules`  
**Severity:** Critical

## Problem
Any doctor could write medicines to any patient's `patients/{patientId}/medicines/` subcollection. No check that a confirmed connection existed.

## Fix Applied
Added `doctorHasPatient(patientId)` check on medicine subcollection `allow create` rule. The function was already defined in rules — only the call site needed adding.

## Related
→ [[Security Overview]]  
→ [[80 - Decisions/ADR-004 Firestore Security Rules]]
