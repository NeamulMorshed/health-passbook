# S-04 — Doctor Patient Check (Prescriptions)

#security

**Status:** ✅ Fixed (v2.11.0+35, ADR-004)  
**File:** `vitalpath_flutter/firestore.rules`  
**Severity:** Critical

## Problem
Any doctor could write to the `prescriptions` collection for any patient — no check for confirmed doctor-patient connection.

## Fix Applied
Added `doctorHasPatient(request.resource.data.patientId)` on `prescriptions` `allow create` rule.

## Related
→ [[Security Overview]]  
→ [[80 - Decisions/ADR-004 Firestore Security Rules]]
