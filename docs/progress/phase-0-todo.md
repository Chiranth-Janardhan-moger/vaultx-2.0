# Phase 0 Todo List — Ingestion & Decisions

**Phase:** Phase 0 — Ingestion & Decisions  
**Owner:** Orchestrator  
**Status:** Completed (Awaiting User Sign-off)  

---

## Numbered Task Checklist

- [x] **0.1** Confirm extraction and structure of prototype assets in `vault_X` (8 screen folders + `sentinel_core`).
- [x] **0.2** Ingest and inspect all 8 screens pairing `code.html` (ground truth) with `screen.png` (visual reference):
  - [x] **0.2.1** `login_sign_up` (Hero branding, dual tabs, biometric trigger)
  - [x] **0.2.2** `passwords_vault` (Passwords list, search, category chips, floating dock, inline modal)
  - [x] **0.2.3** `add_password` (Category picker, form fields, interactive "Swipe to Create" slider)
  - [x] **0.2.4** `edit_password` (Identified blank `screen.png` asset discrepancy; analyzed complete `code.html`)
  - [x] **0.2.5** `password_generator` (Options toggles, custom vertical ruler/ladder slider, strength indicator)
  - [x] **0.2.6** `digital_wallet` (Realistic physical card visual shaders, EMV chip, card network filters)
  - [x] **0.2.7** `add_card` (Card network picker, card number formatter, PIN toggle, security banner)
  - [x] **0.2.8** `settings_theme_switcher` (Appearance, Security, Data, About, Danger Zone, full Light/Dark CSS rules)
- [x] **0.3** Systematically cross-check `sentinel_core/DESIGN.md` YAML frontmatter against rendered HTML/CSS tokens in `code.html` (colors, typography, elevation, border-radius, pill buttons).
- [x] **0.4** Resolve brand name drift between "Sentinel Core", "VaultX", and "VaultX" per §0.2, formulating a firm recommendation and canonical naming convention.
- [x] **0.5** Produce `docs/design-audit.md` containing detailed analysis for each screen:
  - Screen purpose & user flow
  - UI components & layout structure
  - Colors, typography, and styling tokens actually used in code
  - Discrepancies, accessibility issues, and HIG compliance notes
- [x] **0.6** Produce `docs/design-decisions.md` containing:
  - Canonical brand name decision and rationale
  - Token system reconciliation (frontmatter vs markdown body vs HTML implementation)
  - Dark & light theme baseline strategy
  - "Forgot Master Password" security recovery decision
  - Architectural and security assumptions
- [x] **0.7** Review completed todo list against outputs and present `docs/design-audit.md` and `docs/design-decisions.md` to user/senior engineer for sign-off prior to Phase 1.
