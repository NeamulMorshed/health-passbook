# S-01 — Medical Data Exposure

#security

**Status:** ✅ Fixed (v2.11.0+35, ADR-004)  
**File:** `vitalpath_flutter/firestore.rules`  
**Severity:** Critical

## Problem
`allow list: if isSignedIn()` on appointments, prescriptions, vitals — any authenticated user could read ALL medical data for all patients.

## Fix Applied
Changed `allow list` rules to require:
- `resource.data.patientId == request.auth.uid` OR
- `resource.data.doctorId == request.auth.uid` OR
- `isCaregiverFor(patientId)` (for prescriptions/vitals)

## Related
→ [[Security Overview]]  
→ [[80 - Decisions/ADR-004 Firestore Security Rules]]
