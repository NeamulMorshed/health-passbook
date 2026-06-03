---
name: omra-security-check
description: >
  Firestore security pattern checker for Omra. After any Firestore query, security rule
  edit, or Cloud Function change, checks for the 9 known vulnerability patterns from
  AUDIT_REPORT.md Section 3. Prevents re-introducing critical security issues.
  Invoke: /omra-security-check  (runs against the most recently edited file)
---

Check any recently edited Firestore-related file against known Omra security vulnerabilities.

## Group A — Firestore Security Rules Checks (firestore.rules)

- **A-01** `allow list: if isSignedIn()` used without patientId/doctorId/caregiverHasPatient guard on appointments, prescriptions, or vitals collections → **CRITICAL (S-01)**
- **A-02** `users/{userId}` update rule does not exclude `userType` field → user can self-escalate to doctor → **CRITICAL (S-02)**
- **A-03** Medicine subcollection write rule does not call `doctorHasPatient(patientId)` → any doctor writes to any patient → **CRITICAL (S-03)**
- **A-04** Prescription collection write rule does not call `doctorHasPatient()` → any doctor prescribes to any patient → **CRITICAL (S-04)**
- **A-05** Email comparison in caregiver invite rules does not use `.lower()` on both sides → case-sensitive lockout → **HIGH (S-05)**
- **A-06** New collection introduced without a security rule → **HIGH**

## Group B — Firestore Query Checks (Dart code in lib/services/)

- **B-01** Query uses `.where()` + `.orderBy()` together → will fail without composite index; sort client-side instead → **HIGH (ADR-001)**
- **B-02** `Model.fromMap(doc.data(), doc.id)` called without `try-catch` inside a stream `.map()` → one bad document crashes entire stream → **HIGH (ADR-003)**
- **B-03** Query accesses another user's subcollection (e.g., `users/{otherUserId}/medicines`) without verifying caller has permission → **CRITICAL**
- **B-04** Numeric field cast uses `as int?` directly → use `(as num?)?.toInt()` instead → **MEDIUM (ADR-003)**

## Group C — Cloud Functions Checks (functions/src/index.ts)

- **C-01** `conn.caregiverId` referenced anywhere → should be `conn.caregiverUid` → **CRITICAL (S-06)** — FCM push to family members is silently broken
- **C-02** Function queries an entire collection without filtering (e.g., `db.collection('users').get()` in a scheduled function) → O(n) cost scaling → **HIGH (S-07)**
- **C-03** Two sequential `set()`/`update()` writes that should be atomic → use `WriteBatch` or transaction → **HIGH (S-08)**

## Output Format

One line per finding:
```
[SEVERITY] [code] [file:line]: [what was found]. Fix: [remedy]
```

Severity levels: CRITICAL / HIGH / MEDIUM

## Example Output
```
CRITICAL A-01 firestore.rules:34: allow list: if isSignedIn() on /appointments. Fix: add && (resource.data.patientId == request.auth.uid || resource.data.doctorId == request.auth.uid)
HIGH     B-01 lib/services/firestore_service.dart:112: .where('doctorId',...).orderBy('createdAt'). Fix: remove orderBy, sort client-side (ADR-001)
CRITICAL C-01 functions/src/index.ts:89: conn.caregiverId used. Fix: change to conn.caregiverUid
─────────────────────────────────────────────
3 issues found (2 CRITICAL, 1 HIGH).
```

If clean:
```
Security check CLEAN ✓ — no known vulnerability patterns detected.
```
