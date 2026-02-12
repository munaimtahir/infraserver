# Launchpad UI - Visual QA Checklist

This checklist is for verifying the successful implementation of the new minimalist design system.

## Overall Design

- [ ] **Theme:** Is the entire interface using the new light theme?
- [ ] **Background:** Is the main page background `var(--bg)` (`#F7F8FC`)?
- [ ] **Typography:** Is the primary font the system font stack? Are font sizes and weights consistent with the design system?
- [ ] **Spacing:** Is there a clear and consistent rhythm for padding and margins between sections and elements?

## Design Tokens

- [ ] **File:** Does `www/js/design-tokens.css` exist and contain the correct values?
- [ ] **Global Import:** Is `design-tokens.css` imported in `www/js/main.js`?
- [ ] **Usage:** Are hardcoded colors, shadows, and radii replaced with `var(...)` tokens in all updated components?

## Component-Specific QA

### Global Status Bar (`GlobalStatusBar.vue`)
- [ ] **Style:** Is the bar on a `var(--surface)` background with `shadow-sm` and a `border`?
- [ ] **Hierarchy:** Is the overall `HealthBadge` prominent?
- [ ] **Content:** Are the status counts (Healthy, Degraded, Down) and "Last sync" time clear and correctly styled with muted text?

### System Cards (`SystemCard.vue`)
- [ ] **Style:** Do cards have `var(--r-lg)` radius, `var(--border)`, and `var(--shadow-sm)`?
- [ ] **Hover State:** On hover, does the card lift (`translateY`), and do the border and shadow change to `var(--border-strong)` and `var(--shadow-md)`?
- [ ] **Content:** Is the content simplified to Name, HealthBadge, a single meta-data line, and a "View Details" CTA?
- [ ] **Clutter:** Has the "card-body" with multiple metrics been replaced by the single, combined `meta-row`?

### Health Badges (`HealthBadge.vue`)
- [ ] **Style:** Are the badges pill-shaped with soft backgrounds (`--ok-bg`, etc.) and crisp text (`--ok`, etc.)?
- [ ] **Text:** Is the text in Title Case (e.g., "Healthy", not "HEALTHY")?
- [ ] **States:** Do all statuses (Healthy, Degraded, Down, Partial, Unknown) display correctly?

### KPI Metrics Row (`KPIMetricsRow.vue`)
- [ ] **Style:** Has the single row been replaced by a grid of "stat tiles"?
- [ ] **Tile Style:** Do tiles have a `var(--surface)` background and `var(--border)`?
- [ ] **Hierarchy:** Is the number large and the label small and muted?

### Operations Drawer (`OperationsDrawer.vue`)
- [ ] **Appearance:** Does the drawer slide in from the right over a blurred overlay?
- [ ] **Style:** Does it have a `var(--bg)` background and `var(--shadow-lg)`?
- [ ] **Header:** Is the header clean with the app name, status badge, and a functional close button?
- [ ] **Action Grouping:** Are buttons correctly grouped into Primary, Maintenance, Diagnostics, and Danger Zone?
- [ ] **Button Styles:**
    - [ ] `Open App` is a "primary" button.
    - [ ] `Restart All`, `Pull & Restart` are "outline" buttons.
    - [ ] `Verify Public URL`, `Check Health` are "ghost" buttons.
    - [ ] `Stop All Containers` is a "danger" button.
- [ ] **Container List:** Is the list of containers styled with clear items on a `surface` background?

### Collapsible Sections (`CollapsibleSection.vue`)
- [ ] **Style:** Does the section have a `var(--surface)` background with a `border` and `r-md` radius?
- [ ] **Interaction:** Does clicking the header toggle the content visibility?
- [ ] **Chevron:** Is there a chevron icon that rotates on open/close?

### Confirmation Modal (`ConfirmationModal.vue`)
- [ ] **Appearance:** Does the modal pop in at the center over a blurred overlay?
- [ ] **Style:** Does it have a `var(--surface)` background, `var(--r-lg)` radius, and `var(--shadow-lg)`?
- [ ] **Input:** Is the confirmation text input styled according to the new system?
- [ ] **Buttons:** Are the "Cancel" (outline) and "Confirm" (danger) buttons styled correctly?

## Micro-interactions & States
- [ ] **Hover:** Do all interactive elements (buttons, cards) have a clear hover state?
- [ ] **Focus:** Can you navigate with the keyboard? Is there a visible focus ring on all interactive elements?
- [ ] **Active:** Do buttons have a subtle `scale(0.99)` transform when actively pressed?
- [ ] **Disabled:** Are disabled buttons correctly styled with 55% opacity and a `not-allowed` cursor?
- [ ] **Loading:** Do buttons show a spinner and disable the text when in a loading state?
