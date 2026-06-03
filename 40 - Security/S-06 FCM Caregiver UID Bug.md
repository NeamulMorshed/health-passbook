# S-06 — FCM Caregiver UID Bug

#security

**Status:** ✅ Fixed  
**File:** `vitalpath_flutter/functions/src/index.ts`  
**Severity:** High (silent failure)

## Problem
`checkMissedDoses` Cloud Function used `conn.caregiverId` to look up FCM token — but the field name in Firestore is `conn.caregiverUid`. All push notifications to family members silently failed — no error, no notification delivered.

## Fix Applied
`conn.caregiverId` → `conn.caregiverUid` in `checkMissedDoses` function.

## Related
→ [[Security Overview]]
