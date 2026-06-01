# Backlog

#backlog

> Source of truth: `.claude/BACKLOG.md` (Claude writes checkboxes there)  
> This note = human-readable overview + open items only

---

## Open Items

### Play Store Submission
- [ ] Enable GitHub Pages on `docs/` folder
- [ ] Paste `https://<user>.github.io/<repo>/privacy-policy.html` into Play Console Privacy Policy field
- [ ] Complete Data Safety form
- [ ] Upload AAB to Play Console internal test track

### Cloud Deploy (pending)
- [ ] `firebase deploy --only functions` — activates ADR-008 appointment notification loop + ADR-015 appointment reminders

### Phase 8 — Clinical Features (deferred)
- [ ] **8b** Lab results
- [ ] **8c** Doctor med-adjustment workflow with audit trail
- [ ] **8d** Chronic-condition trend tracking

### Future Enhancements (not phased yet)
- [ ] Per-user configurable appointment reminder lead time (ADR-015 D1)
- [ ] Drug interaction check on doctor prescription side (ADR-009 D1)
- [ ] Per-medicine reminder times at prescribe time (ADR-009 D2)
- [ ] Day-of appointment reminder (1h before) (ADR-015)
- [ ] Push to caregiver when patient takes dose after nudge (ADR-013)
- [ ] "Profile incomplete" persistent banner (ADR-007 G4 deferred)
- [ ] Refactor `caregiver` filenames/variables to `family_member` (ADR-002 scope)
- [ ] Notification channel toggle bug: `onMessage` doesn't check `_isChannelEnabled` (ADR-008 pre-existing)

---

## Completed Phases

| Phase | Items | Version |
|-------|-------|---------|
| Phase 1 — Security | S-01, S-02, S-03, S-04, S-05, S-06, S-07, S-08 | v2.11.0+35 |
| Phase 2 — Core UX | UX-1 through UX-7, T-02 | v2.11.0+35 |
| Phase 3 — Collaboration | UX-8 through UX-12, S-05, S-07 | v2.11.0+35 |
| Phase 4 — Polish | UX-13 through UX-18, T-01, T-03, T-04 | v2.11.0+35 |
| Phase 6 — Quick wins | 6a through 6g | v2.11.0+35 |
| Phase 7 — Cross-user comms | 7a, 7b, 7c | v2.11.0+35 |
| Phase 8a | Prescription safety checks | v2.11.0+35 |
| Phase 9 — Accessibility | 9a, 9b, 9c | v2.11.0+35 |
| Play Store | Signing, disclaimer, privacy policy | v2.12.0+41 |
| Crashlytics | Activated with user attribution | v2.12.0+38 |
