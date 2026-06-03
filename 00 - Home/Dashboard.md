# Omra — Project Dashboard

**Version:** 2.12.0+41  
**Branch:** chore/workflow-claude-setup  
**Platform:** Flutter + Firebase  
**Package:** com.vitalpath.app  

---

## Quick Links

### Project
- [[10 - Project/Tech Stack]]
- [[10 - Project/File Map]]
- [[10 - Project/Three Portals]]

### Work
- [[20 - Features/Backlog]]
- [[60 - Sessions/Session Log]]

### Reference
- [[30 - Architecture/Architecture Overview]]
- [[40 - Security/Security Overview]]
- [[50 - UX + Design/Personas]]
- [[80 - Decisions/ADR Index]]
- [[90 - Business/Business Overview]]

---

## Phase Status

| Phase | Focus | Status |
|-------|-------|--------|
| 1 | Security fixes | ✅ Complete |
| 2 | Core UX workflow | ✅ Complete |
| 3 | Collaboration features | ✅ Complete |
| 4 | Polish & accessibility | ✅ Complete |
| 6 | Quick UX wins | ✅ Complete |
| 7 | Cross-user communication | ✅ Complete |
| 8 | Clinical features | 🔲 8b–8d deferred |
| 9 | Accessibility | ✅ Complete |
| Play Store | Submission | 🔲 GitHub Pages → Privacy Policy URL |

---

## Today's Focus
<!-- Update each session -->

---

## Open Items

- [ ] Enable GitHub Pages on `docs/` folder
- [ ] Paste Privacy Policy URL into Play Console
- [ ] Complete Data Safety form
- [ ] Upload AAB to Play Console internal test track
- [ ] Run `firebase deploy --only functions` (ADR-008, ADR-015 not yet deployed)
- [ ] Lab results — 8b (deferred)
- [ ] Doctor med-adjustment workflow — 8c (deferred)
- [ ] Chronic-condition trend tracking — 8d (deferred)

---

## Recent Sessions

```dataview
TABLE file.mtime AS "Last Modified"
FROM "60 - Sessions"
SORT file.mtime DESC
LIMIT 5
```

---

## Open ADRs

```dataview
TABLE status AS "Status", file.mday AS "Date"
FROM "80 - Decisions"
WHERE contains(status, "pending") OR contains(status, "⚠")
SORT file.mtime DESC
```

---

## Security Notes

```dataview
LIST
FROM "40 - Security"
SORT file.name ASC
```

---

## Firebase Console
- **Project:** health-passbook-9a0df
- **Distribution App ID:** `1:768599207887:android:a365080e6a086985736cba`
- **Deploy APK:** `firebase appdistribution:distribute <path>.apk --app 1:768599207887:android:a365080e6a086985736cba --groups testers`
- **Deploy rules:** `firebase deploy --only firestore:rules`
- **Deploy functions:** `firebase deploy --only functions` (from `vitalpath_flutter/`)
