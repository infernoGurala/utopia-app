# UTOPIA — Today's Brief
## 02 — News Feed Screen UI Spec

### Screen Entry
- Opens when user taps the dashboard block
- Navigation: push route or modal bottom sheet — **use whichever matches UTOPIA's existing nav pattern**
- Back: standard back button or swipe-down gesture to close

---

### Screen Layout (Top to Bottom)

```
─────────────────────────────────────
  ← Back         Today's Brief
                 Wednesday, 20 May 2026
                 Updated at 6:00 AM
─────────────────────────────────────
  [ World ] [ Tech ] [ Economy ] [ Sports ] [ Culture ] [ India ]
─────────────────────────────────────
  ┌────────────────────────────────┐
  │ BBC · 2h ago                   │
  │ Headline of the article        │
  │ Key fact in one sentence.      │
  │ Short AI paragraph here. 2–3   │
  │ sentences. Plain language.     │
  └────────────────────────────────┘
  ┌────────────────────────────────┐
  │ Reuters · 4h ago               │
  │ ...                            │
  └────────────────────────────────┘
  ... (4–5 cards max per category)
─────────────────────────────────────
```

---

### Header

| Element | Detail |
|---------|--------|
| Back button | Top-left, standard UTOPIA back/close icon |
| Title | "Today's Brief" — large, bold |
| Date | Full date below title — muted color |
| Update time | "Updated at 6:00 AM" — smallest size, muted |

---

### Category Tabs

- Horizontal scrollable chip row below the header
- Chips: World, Science & Tech, Economy, Sports, Culture, India
- **Active chip:** filled with `accentPrimary` color, white/dark label depending on theme
- **Inactive chip:** outlined or muted fill, `textSecondary` label
- Only one tab active at a time
- Default active tab on open: **World**
- Tab switching is instant — no loading animation between tabs (all data already loaded)

---

### News Card

Each card in the feed:

```
┌──────────────────────────────────────┐
│  SOURCE NAME · X hours ago           │  ← textMuted, smallest size
│                                      │
│  Headline of the Article             │  ← textPrimary, bold, 16sp
│                                      │
│  One key fact sentence.              │  ← accentPrimary or textSecondary, 13sp
│                                      │
│  Short AI paragraph. 2–3 sentences.  │  ← textSecondary, 13sp, normal weight
│  Plain language. No jargon.          │
└──────────────────────────────────────┘
```

#### Card Rules
- **No images** on cards
- **Not tappable** — cards are purely display
- Card background: `cardBackground` theme token
- Border radius: match UTOPIA card style
- Vertical spacing between cards: consistent with dashboard card spacing
- Maximum **5 cards per category tab** — never more
- If fewer articles are available for a category, show what exists (minimum 2)

---

### Empty / Error States

| State | Display |
|-------|---------|
| Category has no articles | Show a single muted card: "Nothing to show in this category today." |
| Network error on screen open | Show full-screen message: "Today's Brief couldn't load. Check your connection." with a retry button |
| Loading (first open of the day before cache exists) | Show skeleton shimmer cards (3 placeholder cards per tab) |

---

### Scroll Behavior
- Each category tab has its own **independent scroll position**
- Switching tabs does not reset other tabs' scroll
- Screen is scrollable — no fixed height constraints on card list

---

### Visual Style Rules
- Screen background: `pageBackground` theme token (matches UTOPIA's existing screen backgrounds)
- All cards: `cardBackground` theme token
- No dividers between cards — use vertical gap spacing only
- Typography scale must match UTOPIA's existing type system exactly
- Do not introduce any new font or font weight not already used in UTOPIA
