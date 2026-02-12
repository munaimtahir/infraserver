# Al-Shifa Launchpad - Design System

This document outlines the visual language and core components of the Launchpad UI. The system is designed to be calm, confident, analytical, and minimalist, prioritizing clarity and ease of use in an enterprise operations context.

## 1. Design Tokens

The UI is built upon a system of CSS variables (design tokens) that ensure consistency across the application.

### Base Palette

- ` --bg`: #F7F8FC *(Page background)*
- ` --surface`: #FFFFFF *(Primary content surface, e.g., cards)*
- ` --surface-2`: #F2F4F8 *(Secondary panels, e.g., accordion content)*
- ` --border`: rgba(15, 23, 42, 0.08) *(Standard border)*
- ` --border-strong`: rgba(15, 23, 42, 0.14) *(Hover/active border)*

### Text Palette

- ` --text`: #0B1220 *(Primary text)*
- ` --muted`: rgba(11, 18, 32, 0.70) *(Secondary text)*
- ` --muted-2`: rgba(11, 18, 32, 0.55) *(Tertiary text)*

### Brand Accent

- ` --primary`: #1D4ED8 *(Primary interactive color)*
- ` --primary-hover`: #1E40AF *(Primary hover state)*
- ` --primary-bg`: rgba(29, 78, 216, 0.07) *(Soft primary background)*

### Status Palette

| Status  | Text Color | Background Color         |
| :------ | :--------- | :----------------------- |
| OK      | `--ok`     | `--ok-bg`                |
| Warning | `--warn`   | `--warn-bg`              |
| Bad     | `--bad`    | `--bad-bg`               |
| Partial | `--partial`| `--partial-bg`           |
| Unknown | `--unknown`| `--unknown-bg`           |

### Shadows & Elevation

- ` --shadow-sm`: Subtle shadow for cards.
- ` --shadow-md`: Hover shadow for cards.
- ` --shadow-lg`: Prominent shadow for modals and drawers.
- ` --shadow-xl`: Large, diffuse shadow for overlays.

### Radii

- ` --r-sm`: 6px
- ` --r-md`: 12px
- ` --r-lg`: 16px

### Transitions

- ` --t-fast`: 120ms (for subtle interactions)
- ` --t-base`: 180ms (for base component animations)

## 2. Component Variants

### Buttons (`ActionButton`)

- **Primary**: Solid background (`--primary`). Used for the main positive action.
- **Outline**: Transparent background with a strong border. Used for secondary maintenance actions.
- **Ghost**: Transparent background, no border. Used for tertiary actions like diagnostics.
- **Danger**: Red border and text. Used for destructive actions.
- **Disabled**: Reduced opacity and `cursor: not-allowed`.
- **Loading**: Shows an animated spinner and disables the button.

### Health Badges

Pill-shaped badges with soft, colored backgrounds and crisp, corresponding text colors. Used to indicate the status of systems and containers.

### Cards (`SystemCard`)

- **Base**: `surface` background, `border`, `r-lg` radius, `shadow-sm`.
- **Hover**: Lifts with `translateY(-2px)`, `shadow-md`, and a `border-strong`.

### Drawer (`OperationsDrawer`)

- A right-sided "sheet" that slides in over a blurred backdrop.
- Uses `shadow-lg` for elevation.
- Contains `CollapsibleSection` components for organizing content.

### Modal (`ConfirmationModal`)

- A centered "sheet" that appears over a blurred backdrop with a `popIn` animation.
- Uses `shadow-lg` for elevation.
- Contains `ActionButton` variants for actions.
