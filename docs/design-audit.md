# VaultX — Design Audit Report (Phase 0)

**Date:** 2026-09-07  
**Auditor:** Orchestrator / Architect & Security Engineer  
**Scope:** Complete cross-audit of 8 prototype screens (`code.html` as ground truth, `screen.png` as visual reference) against `sentinel_core/DESIGN.md`.

---

## Executive Summary

The prototype export contains 8 screens defining an offline-capable, local-first password and digital card vault. A rigorous review comparing `screen.png` visual mockups and `code.html` DOM/CSS implementations revealed multiple divergence points between the design specification (`sentinel_core/DESIGN.md`), the frontmatter tokens, and the practical implementation across screens. 

Notably:
1. `edit_password/screen.png` was exported as a corrupted/blank 4KB black image; however, `edit_password/code.html` is complete and fully functional (267 lines of code).
2. The brand identity drifted across three names: "Sentinel Core" (frontmatter metadata), "VaultX" (on-screen hero logo, typography, and storage keys), and "VaultX" (host folder name).
3. `DESIGN.md` frontmatter defines a pastel M3 token scheme (`primary: #bec6e0`, `secondary: #a9c7ff`), whereas the actual screens consistently utilize a deep OLED dark palette (`#020617` / `#000000`) with high-contrast electric blue (`#0080ff` / `#0088ff`) and purple gradient accents.
4. Component geometry across screens utilizes fully-rounded pills (`rounded-full`, `rounded-2xl`, `rounded-[32px]`), diverging from the frontmatter's default `rounded: 0.5rem (8px)`.

---

## Detailed Screen-by-Screen Audit

### Screen 1: Login / Sign Up (`login_sign_up`)
- **Purpose & User Flow:** Cold-start gateway gating access to the encrypted vault. Supports dual modes via segmented tab switcher: "Log In" (Email, Master Password, Biometric unlock, Forgot Password trigger) and "Sign Up" (Email, Master Password, Confirm Password, Account creation).
- **Layout & Structure:**
  - Vertically centered card container on deep dark background (`bg-background` `#101415`).
  - Hero header with lock avatar (`lock_person`) displaying a dynamic gradient (`linear-gradient(135deg, #0088ff, #a855f7)`) and stylized wordmark **VaultX** (`linear-gradient(90deg, #0088ff, #a855f7)`).
  - Tagline: *"Your mind, secured."*
  - Form container in elevated dark surface (`#1a1a1a`) with rounded corners (`rounded-[32px]`) and subtle border (`#2a2a2a`).
  - Segmented control pills for Log In / Sign Up (`#2a2a2a` container, `#1a1a1a` active pill).
  - Field blocks: Email, Master Password (with show/hide eye toggle), Confirm Password (in sign-up mode).
  - Main CTA: Full-width vibrant blue button (`#0088ff` / `#0080ff`, `rounded-xl`, hover transition, active scale animation).
  - Biometric quick-access block: Blue fingerprint icon (`#0088ff`, 48px) + "Tap to Unlock" action.
  - End-to-end encryption security guarantee badge in footer.
- **Colors & Tokens Actually Used in Code:**
  - Background: `#101415`
  - Container / Card: `#1a1a1a`
  - Input field fill: `#2a2a2a`
  - Border stroke: `#2a2a2a`
  - Primary Accent: `#0088ff` (Brand Blue), gradient pairing `#a855f7` (Brand Purple)
  - Success State: `#059669` / `#10b981` (Emerald 600)
  - Error State: `#ff5252` border, red-950/40 banner
  - Typography: Hanken Grotesk (Headline), Inter (Body, Buttons), JetBrains Mono (Labels)
- **Discrepancies & HIG Notes:**
  - *Color Contrast:* Placeholder text `text-on-surface-variant` (`#c6c6cd`) on `#2a2a2a` inputs achieves >4.5:1 ratio (passes WCAG AA).
  - *Accessibility / Touch Targets:* Input height is ~48px; primary button is 48px; biometric target is >48x48px (meets HIG 44x44pt requirement).
  - *Validation Feedback:* Code features real-time validation with visual shake animation and red warning banners.

---

### Screen 2: Passwords Vault / Home (`passwords_vault`)
- **Purpose & User Flow:** Primary home dashboard displaying all stored credentials, dynamic search, category filtering, item count badge, and quick addition. Tapping any entry opens an in-place modal/sheet with full detail inspection and editing.
- **Layout & Structure:**
  - Sticky Top App Bar with bold "Passwords" title (`text-[28px]`), quick Add action button (`+` pill in `#0080ff`).
  - Search field with magnifying glass icon (`bg-[#000000]`, border `white/10`, rounded-full).
  - Horizontal scrolling category filter pills: "All", "Email", "Instagram", "Bank", "GitHub", "Entertainment" (rounded-full).
  - Item counter badge (e.g. "2 Items", "5 Items").
  - Password Entry Cards (`rounded-2xl`, `bg-[#191c1e]`, border `white/5`):
    - Leading rounded square icon (`w-14 h-14`, `#323537` bg, `#0080ff` icon: `vpn_key`, `movie`, `account_balance`, `work`, `photo_camera`).
    - Service title, username/email subtitle, relative timestamp ("Edited 10m ago").
    - Trailing disclosure chevron.
  - Floating Bottom Navigation Dock (Pill):
    - Capsule bar (`bg-[#25282a]/95`, backdrop-blur, rounded-full) containing 4 tabs: Passwords (active `#0080ff` pill), Wallet, Generator, Settings.
  - Embedded Detail & Edit Sheet: Includes credential copy actions, unmask toggle, breach health badge, URL launcher, notes, and Delete Password button.
- **Colors & Tokens Actually Used in Code:**
  - Background: `#020617` (Deepest Slate Navy)
  - Card Surface: `#191c1e`
  - Icon container: `#323537`
  - Primary Blue: `#0080ff`
  - Text: `#ffffff` (Heading), `#a0a5aa` / `#c6c6cd` (Muted/Subtitles)
  - Health Banner: Emerald green (`bg-emerald-950/40`, border `emerald-500/20`, text `emerald-400`)
- **Discrepancies & HIG Notes:**
  - The background is explicitly `#020617` (rich black/navy), distinct from `DESIGN.md`'s `#101415`.
  - The floating bottom navigation dock floats 24px above the bottom; must ensure proper `SafeArea` padding on iOS/Android home indicators.

---

### Screen 3: Add Password (`add_password`)
- **Purpose & User Flow:** Modal/form screen allowing creation of a new password record, category selection, password generation via an interactive gesture slider ("Swipe to Create"), and notes capture.
- **Layout & Structure:**
  - Top Navigation Bar: "Cancel" (left, blue text), "Add Password" (centered bold), "Save" (right, blue bold text).
  - Category Picker: Section title "CHOOSE CATEGORY", active glyph circular indicator (`#active-icon-badge`), horizontal scrollable pill chips ("General", "Email", "Instagram", "Google", "Bank", "GitHub", "Entertainment", "+ Add Category").
  - Form Section 1 (Identity): Grouped rounded container (`bg-vaultSurface` `#191d20`) with dividers between Name, Username, and Email.
  - Form Section 2 (Password & Generator Slider):
    - Masked password input with eye toggle.
    - Interactive "Swipe to Create Password" slider track (`h-12`, `rounded-full`, bg `#101415`, border `#262b30`, animated shimmer text, draggable `#0080ff` thumb with `auto_awesome` spark icon).
  - Form Section 3 (Metadata): URL field (monospace font), Notes multiline field, category confirmation badge (`• General`).
- **Colors & Tokens Actually Used in Code:**
  - Background: `#050708` (`vaultDark`)
  - Input container: `#191d20` (`vaultSurface`), dividers `#262b30`
  - Accent: `#0080ff` (`vaultAccent`), hover `#006ee0`
  - Muted labels: `#8b949e`, `#a0aab4`
  - Shimmer text: linear gradient animation (`rgba(139,148,158,0.7)` to `rgba(255,255,255,0.95)`)
- **Discrepancies & HIG Notes:**
  - Uses custom color alias prefix `vault*` (`vaultDark`, `vaultNavy`, `vaultSurface`, `vaultAccent`) rather than standard Tailwind or `DESIGN.md` names.
  - "Swipe to Create" is a custom gesture control; HIG requires both gesture and accessible tap alternatives (which the JS script implements via thumb click).

---

### Screen 4: Edit Password / View Credential (`edit_password`)
- **Purpose & User Flow:** Detailed credential inspector and editor. Provides read-only security view by default (with instant copy triggers and eye-unmasking) and a toggled "Edit" mode allowing live inline editing and record deletion.
- **Layout & Structure:**
  - Top Bar: Circular Close button (`w-10 h-10`, bg `#1c1d22`), "Edit" / "Done" stateful action button (`#0080ff` transitioning to `#34d399` emerald in edit mode).
  - Service Identity: Large circular avatar (`w-20 h-20`, `#828690`/80) with dynamic first-letter monogram ("E"), editable Service Name title, subtitle username.
  - Credentials Card: Grouped card (`bg-[#16171a]`, border `white/5`) with Username + Copy button, Password (masked monospace dots) + Visibility Eye toggle + Copy button.
  - Security Banner: "Safe & Secure — No leaks detected in known data breaches" with green shield icon (`verified_user`).
  - Details Card: Website URL with external launch icon, multiline Notes area.
  - Danger Zone: Full-width "Delete Password" card button with red text (`#ff453a`).
- **Colors & Tokens Actually Used in Code:**
  - Background: `#000000` (Pure Black)
  - Card: `#16171a`, Card border: `#23252a`
  - Divider: `#202227`
  - Accent: `#0080ff`
  - Danger: `#ef4444`, text `#ff453a`
  - Safety badge: `#0a1f14` bg, `emerald-500/70` border, `emerald-400` icon
- **Discrepancies & HIG Notes:**
  - **Critical Asset Discrepancy:** `edit_password/screen.png` is an unrendered 4KB black file. However, `edit_password/code.html` is 100% complete and matches the inline modal in `passwords_vault`.
  - In edit mode, inputs change from borderless readonly text to styled inputs (`bg-[#1f2128]`, border `white/10`, `rounded-lg`).

---

### Screen 5: Password Generator (`password_generator`)
- **Purpose & User Flow:** Dedicated generator utility allowing users to configure password length, character sets (Uppercase, Lowercase, Numbers, Symbols), evaluate strength, and copy or regenerate with one tap.
- **Layout & Structure:**
  - Screen Header: "Generator" (`text-3xl font-bold`).
  - Output Display Card (`bg-[#191c1e]`, `rounded-3xl`, border `#232729`):
    - Large centered monospace password text (`break-all`, font size 28-32px).
    - Dynamic strength label directly below ("Strong" in `#10b981`, "Medium" in `#f59e0b`, "Weak" in `#ef4444`).
    - Action Controls: Circular reload button (`w-14 h-14`, `#272a2c` bg, `#0080ff` icon) + Wide pill Copy button (`bg-[#0080ff]`, `h-14`, `rounded-full`).
  - Dual Controls Section:
    - Left Panel: 4 toggle rows (Uppercase A-Z, Lowercase a-z, Numbers 0-9, Symbols !@#$%^&*) with iOS-style pill switches (`peer-checked:bg-[#0080ff]`).
    - Right Panel: Custom vertical "ruler/ladder" slider widget (`w-[68px]`, bg `#0c0e10`, ruler tick rungs, glowing blue slider thumb `#0080ff`, supports drag, wheel scroll, and direct tap).
  - Floating Bottom Navigation Dock: Generator tab active.
- **Colors & Tokens Actually Used in Code:**
  - Base: `#101415`
  - Card: `#191c1e`, Border: `#232729`
  - Track background: `#0c0e10`
  - Accent: `#0080ff` with glow shadow `rgba(0, 128, 255, 0.35)`
  - Rungs: `#353b42`
  - Strength colors: Emerald (`#10b981`), Amber (`#f59e0b`), Red (`#ef4444`)
- **Discrepancies & HIG Notes:**
  - The vertical ruler slider is an intuitive, tactile custom component. For accessibility and cross-platform consistency, Flutter implementation must provide standard Semantics (slider role with value updates) and support both drag and discrete step taps.

---

### Screen 6: Digital Wallet (`digital_wallet`)
- **Purpose & User Flow:** Overview of payment cards, credit cards, and secure notes. Provides realistic physical card representations, card network filtering, card number unmasking, sharing, and quick actions.
- **Layout & Structure:**
  - Top Bar: "Wallet" title, Search input, "+" Add Card round button.
  - Filter Pills: "All", "Visa", "Mastercard", "Plexee", "Amex".
  - Subheader: Card counter (e.g. "3 Cards") + instructions "TAP TO VIEW • HOLD FOR MENU".
  - Physical Realistic Card Representations (Aspect ratio `1.586 : 1`, rounded `1.25rem`, sheen gradient overlay):
    - **Chase Sapphire Reserve:** Deep navy gradient (`#0a192f` to `#040d1a`), VISA logo, golden EMV chip, contactless wave symbol, masked number `•••• •••• •••• 7890`, eye toggle, Cardholder "ALEXANDER DRAFT", Expiry "EXP 08/28".
    - **Apple Card Titanium:** Metallic titanium gradient, Mastercard dual-circle logo, EMV chip, masked number `•••• •••• •••• 2345`, Cardholder name, Expiry "EXP 11/27".
    - **Plexee Sovereign:** Bronze-gold gradient, Plexee emblem, EMV chip, masked number `•••• •••• •••• 5519`, Cardholder name, Expiry "EXP 05/30".
  - Floating Bottom Navigation Dock: Wallet tab active.
- **Colors & Tokens Actually Used in Code:**
  - Background: `#0b0f10` / `#020617`
  - EMV Chip: Gold gradient (`#e5c365` to `#ffd700`) with micro-lines
  - Accent: `#0080ff`
  - Card gradients: Navy (`#0a192f`), Titanium slate (`#1c2024` to `#0f1215`), Bronze (`#2a1f0a` to `#140f05`)
- **Discrepancies & HIG Notes:**
  - Card cards feature micro-actions (share, more_vert menu, eye unmask). Touch targets must remain at least 44x44pt on touchscreens to prevent accidental mis-taps.

---

### Screen 7: Add Card (`add_card`)
- **Purpose & User Flow:** Card ingestion form allowing users to select payment network, enter title, cardholder name, card number with live formatting, expiry date, PIN/CVV, and encrypted notes.
- **Layout & Structure:**
  - Top Bar: "Cancel", "Add Card", "Save" (text actions).
  - CARD NETWORK Selector: 4 network buttons (Visa with default badge, Mastercard with red/amber overlapping discs, Amex with cyan text, Plexee with wallet icon). Selected network highlighted with `#0080ff` 2px border.
  - Input Group 1 (Identity): Title ("e.g. Personal Chase Visa"), Name ("e.g. John Doe") in grouped card container (`bg-surface-card` `#151b26`).
  - Input Group 2 (Card Credentials):
    - Card Number input (16-19 digits, auto-spaced every 4 digits, monospace) + clipboard paste icon.
    - Two-column split row: Expiry (`MM/YY`, monospace) and PIN (`••••`, monospace) with eye unmask toggle.
  - Input Group 3 (Details & Notes): Notes textarea with "Offline Encrypted" pill.
  - Security Guarantee Banner: Emerald shield lock + "100% Offline Vault. Card data and PIN are encrypted on-device with AES-256 and never transmitted over any network."
  - Bottom CTA: Full-width blue pill button `(+) Save to Wallet`.
- **Colors & Tokens Actually Used in Code:**
  - Background: `#07090e`
  - Card container: `#151b26`
  - Inputs: `#1b2230`
  - Accent: `#0080ff`, hover `#0070e0`
  - Security banner: `bg-emerald-950/20`, border `emerald-500/20`, text `emerald-400`
- **Discrepancies & HIG Notes:**
  - PIN and Card Number fields require strict numeric-only keyboard (`TextInputType.number`) and automatic formatters in Flutter.

---

### Screen 8: Settings & Theme Switcher (`settings_theme_switcher`)
- **Purpose & User Flow:** Comprehensive preferences center containing Appearance (theme mode switcher), Security (change master password, biometric toggle, auto-lock timeout), Data Management (Sync with Desktop, Backup Vault, Import), About (Security Guide, App Info, Rate App), and Danger Zone (Wipe All Data).
- **Layout & Structure:**
  - Screen Header: "Settings" (`text-3xl font-extrabold`).
  - Appearance Group: "App Theme" row displaying current state ("Light Mode" / "Dark Mode") and active theme badge.
  - Theme Switcher Modal Overlay:
    - Backdrop blur modal dialog (`bg-[#181c20]`, rounded-2xl, border `white/10`).
    - Segmented two-button toggle: "Light Mode" (sun icon) vs. "Dark Mode" (moon icon).
    - Blue "Done" action button.
  - Security Group:
    - "Change Password" row (key icon, chevron).
    - "Touch ID" / Biometric row with interactive switch toggle.
    - "Auto-Lock" row ("Immediately", toggle switch).
  - Data Management Group:
    - "Sync with Desktop" (refresh/sync icon).
    - "Backup Vault" (cloud/vault export icon).
    - "Import Passwords" (import tray icon).
  - About Group: "Security Guide", "App Info", "Rate App".
  - Danger Zone: "Wipe All Data" with red trash can icon and "IRREVERSIBLE" badge.
  - Floating Bottom Navigation Dock: Settings active.
- **Colors & Tokens Actually Used in Code:**
  - Dark Theme: Bg `#000000` / `#0b0f10`, cards `#181b1e`, dividers `#272b30`/80.
  - Light Theme (already fully specified in CSS lines 66-158):
    - Body Background: `#f8fafc`
    - Card Container: `#ffffff` with border `#e2e8f0`
    - Text: `#0f172a`, Muted text: `#64748b`
    - Nav dock: `rgba(255, 255, 255, 0.92)`, border `#e2e8f0`
    - Modal card: `#ffffff`, border `#e2e8f0`, text `#0f172a`
  - Accent: `#0080ff`
  - Danger: `#ef4444`, text `#ff453a`, container `border-red-500/10`
- **Discrepancies & HIG Notes:**
  - This screen provides the exact pairing formulas for Light Mode vs Dark Mode, verifying that both themes can share semantic color roles cleanly.

---

## Token Comparison Matrix

| Token Role | `DESIGN.md` Frontmatter | `DESIGN.md` Body Text | Rendered `code.html` (Dark) | Proposed Flutter Semantic Role |
|---|---|---|---|---|
| **App Name** | "Sentinel Core" | N/A | **VaultX** | `VaultX` |
| **Primary Accent** | `#bec6e0` (Light Slate) | `#0084ff` (Vibrant Blue) | `#0080ff` / `#0088ff` | `ColorScheme.primary = Color(0xFF0080FF)` |
| **Secondary Accent** | `#a9c7ff` (Sky) | `#64748B` (Slate Gray) | `#a855f7` (Violet gradient) | `ColorScheme.secondary = Color(0xFFA855F7)` |
| **Background (Dark)** | `#101415` | `#0F172A` | `#020617` / `#0B0F10` | `ColorScheme.surface = Color(0xFF020617)` |
| **Background (Light)** | Unspecified | Unspecified | `#f8fafc` | `ColorScheme.surface = Color(0xFFF8FAFC)` |
| **Card Surface (Dark)**| `#191c1e` | `#1E293B` | `#191c1e` / `#16171a` | `ColorScheme.surfaceContainer = Color(0xFF191C1E)` |
| **Card Surface (Light)**| Unspecified | Unspecified | `#ffffff` | `ColorScheme.surfaceContainer = Color(0xFFFFFFFF)` |
| **Success / Safe** | N/A | N/A | `#10b981` / `#34d399` | `AppColors.emerald500 = Color(0xFF10B981)` |
| **Warning** | N/A | `#EF4444` | `#f59e0b` / `amber-500` | `AppColors.amber500 = Color(0xFFF59E0B)` |
| **Danger / Error** | `#ffb4ab` | `#EF4444` | `#ef4444` / `#ff453a` | `ColorScheme.error = Color(0xFFEF4444)` |
| **Border Radius** | 8px (default), 16px (lg) | 8px / 16px | Fully rounded pills (`9999px`) | Pills for CTAs/Chips; 16-24px for Cards |
| **Typeface** | Hanken Grotesk / Inter | Hanken Grotesk / Inter / JetBrains Mono | Hanken Grotesk / Inter / JetBrains Mono | Headings: Hanken Grotesk; Body: Inter; Data: JetBrains Mono |
