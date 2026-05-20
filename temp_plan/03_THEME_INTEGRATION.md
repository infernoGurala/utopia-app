# UTOPIA — Today's Brief
## 03 — Theme Integration Spec

### Principle
The News feature must use **only existing UTOPIA theme tokens**. It must never hardcode colors, never introduce new color values, and never look out of place in any of the 8 themes.

---

### Token Mapping

The News feature uses the following semantic tokens. These must be sourced from UTOPIA's existing theme system:

| Token Name | Used For |
|------------|----------|
| `pageBackground` | News Feed screen background |
| `cardBackground` | Dashboard block background + news cards |
| `textPrimary` | Card headline, screen title |
| `textSecondary` | AI summary paragraph, source name |
| `textMuted` | Update time, timestamp, category count |
| `accentPrimary` | Active category chip fill, key fact sentence color, icon color |
| `accentMuted` | Icon container background on dashboard block |
| `chipActive` | Active tab chip — if UTOPIA already has this token, use it |
| `chipInactive` | Inactive tab chip — if already defined, use it |
| `shimmerBase` | Loading skeleton base color |
| `shimmerHighlight` | Loading skeleton shimmer highlight color |

> **Instruction for coding agent:** Do not define these token values yourself. Map to whatever tokens already exist in UTOPIA's theme provider for equivalent purposes. If a token doesn't exist by this exact name, use the nearest equivalent already in the codebase.

---

### Theme Behavior Rules

1. **The feature never sets a hardcoded color anywhere.** Every color reference must be a theme token lookup.

2. **The dashboard block background must match the other cards on the home screen exactly.** It should be visually indistinguishable in style from the `Daily Note` and `Activity` cards.

3. **The active category chip uses `accentPrimary`.** This ensures it matches the theme's accent — gold/amber in warm themes, blue/teal in cool themes, etc.

4. **The key fact sentence (one-liner below headline) should use `accentPrimary` color** — giving it visual hierarchy above the body paragraph, and naturally adapting to each theme's accent.

5. **On themes with a light background:** Cards must still be legible. Since all tokens are from the existing system, this is handled automatically — do not special-case for light vs dark.

6. **Shimmer loading animation:** Uses `shimmerBase` and `shimmerHighlight` from the theme. If UTOPIA has a shared `SkeletonLoader` widget, use it. Do not build a new one.

---

### Theme Checklist for QA

Before shipping, manually verify the feature looks correct in all 8 themes:

- [ ] Theme 1 — check dashboard block blends with existing cards
- [ ] Theme 2 — check active chip accent color matches theme
- [ ] Theme 3 — check text legibility on all card types
- [ ] Theme 4 — check icon container color is not jarring
- [ ] Theme 5 — check shimmer animation is visible
- [ ] Theme 6 — check key fact line is visually distinct but not clashing
- [ ] Theme 7 — check screen background matches rest of app
- [ ] Theme 8 — check full feature end-to-end in this theme

> Replace theme numbers with actual theme names once confirmed.
