# Business Overview

#business

## App Identity
- **Name:** Omra
- **Old name:** VitalPath (fully replaced in UI)
- **Package:** com.vitalpath.app
- **Platform:** Flutter Android (iOS not yet)
- **Category:** Personal health monitoring + family care coordination

## Target Market
- Bangladesh (primary)
- Informal family caregiving model
- Patients with chronic conditions (diabetes, hypertension)
- Their family members who monitor remotely
- Outpatient doctors managing multiple patients

## Value Proposition
- Patient: never miss a medicine dose, track vitals, coordinate with doctor
- Doctor: at-a-glance patient health status, prescription workflow, direct messaging
- Family Member: know if loved one is OK without being intrusive

## Business Model Documents
- `Omra_Business_Model_Bangladesh.docx`
- `Omra_Business_Model_Complete.docx`
- `Omra_Business_Model_PolicyCompliant.docx`

## Play Store Submission Status
- **Version:** 2.12.0+41 (AAB built and signed)
- **Signing:** Release keystore (`omra-release.jks`) — NOT in git
- **Privacy policy:** `docs/privacy-policy.html` — needs GitHub Pages enabled
- **Disclaimer:** Implemented (first-launch, SharedPreferences-gated)
- **Account deletion:** `docs/delete-account.html` — required by Play Store

## Distribution
- **Internal testing:** Firebase App Distribution
- **Testers:** neamul.morshed.nahid@gmail.com
- **Production target:** Google Play Store (submission in progress)

## Firebase Project
- **ID:** health-passbook-9a0df
- **Region:** Default
