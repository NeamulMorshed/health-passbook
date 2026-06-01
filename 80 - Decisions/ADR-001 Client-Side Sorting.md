# ADR-001 — Client-Side Sorting

#adr #architecture

**Date:** 2026-05  
**Status:** ✅ Implemented (v2.11.0+34)

## Decision
Remove `.orderBy()` from all Firestore queries. Sort resulting list client-side.

## Reason
`.orderBy()` + `.where()` together require a composite Firestore index. Missing index caused "Failed to load" on doctor dashboard. Client-side sort on <100 items has negligible cost.

## Pattern
```dart
.snapshots().map((s) {
  final items = s.docs.map(...).whereType<T>().toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return items;
})
```

## Affected Files
`lib/services/firestore_service.dart` — `watchDoctorAppointments`, `watchPatientAppointments`

## Do NOT Reintroduce
Any `.orderBy()` + `.where()` combination without first deploying the matching index in `firestore.indexes.json`.

→ [[ADR Index]]
