# Security Overview

#security

## Status: All Critical Issues Fixed ✅

All Phase 1 security vulnerabilities resolved. See individual notes for detail.

## Vulnerability Index

| ID | Summary | Status | Note |
|----|---------|--------|------|
| S-01 | Any signed-in user reads ALL medical data | ✅ Fixed (v2.11.0+35) | [[S-01 Medical Data Exposure]] |
| S-02 | User can self-escalate to doctor role | ✅ Fixed (v2.11.0+35) | [[S-02 Role Self-Escalation]] |
| S-03 | Any doctor prescribes to any patient | ✅ Fixed (v2.11.0+35) | [[S-03 Doctor Patient Check — Medicines]] |
| S-04 | Any doctor prescribes to any patient | ✅ Fixed (v2.11.0+35) | [[S-04 Doctor Patient Check — Prescriptions]] |
| S-05 | Case-sensitive email invite comparison | ✅ Fixed (v2.11.0+35) | [[S-05 Email Case Sensitivity]] |
| S-06 | FCM to family members silently fails | ✅ Fixed | [[S-06 FCM Caregiver UID Bug]] |
| S-07 | O(n) Cloud Function queries all patients | ✅ Fixed (v2.11.0+35) | [[S-07 Cloud Function Performance]] |
| S-08 | Caregiver invite not atomic | ✅ Fixed | [[S-08 Invite WriteBatch]] |

## Rules File
`vitalpath_flutter/firestore.rules`

## Deploy Status
⚠ Rules changes require `firebase deploy --only firestore:rules`  
⚠ Functions changes require `firebase deploy --only functions` (from `vitalpath_flutter/`)

## Key Helper Functions in Rules
- `isSignedIn()` — basic auth check
- `isOwner(uid)` — `request.auth.uid == uid`
- `isCaregiverFor(patientId)` — active connection exists
- `doctorHasPatient(patientId)` — confirmed connection exists
- `caregiverCanRead(patientId, section)` — per-section permission check (ADR-011)
