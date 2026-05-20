# UTOPIA — Today's Brief
## 01 — Dashboard Block UI Spec

### Placement
- Located at the **bottom of the home dashboard**, in the same slot as the existing quote/motivation card
- Sits below the `Activity` row
- Above the bottom navigation bar
- Full width, same horizontal padding as other dashboard cards

---

### Widget Structure

```
[ Globe Icon ]   Today's Brief                          [ › ]
                 {TOP_HEADLINE_ONE_LINE}
                 5 categories · Updated 6:00 AM
```

#### Elements Breakdown

| Element | Description |
|---------|-------------|
| **Left Icon** | Small globe or newspaper icon — matches the icon style of `Activity` card (square icon container, accent background) |
| **Title** | "Today's Brief" — same font weight and size as "Activity" title |
| **Subtitle line 1** | Top headline of the day — single line, truncated with ellipsis if too long — muted text color |
| **Subtitle line 2** | "5 categories · Updated 6:00 AM" — smallest text size, most muted color |
| **Right Arrow** | Same `›` chevron used on Daily Note, Reminders, Activity cards |

---

### Behavior
- Entire block is tappable — opens the News Feed Screen (see `02_UI_NEWS_FEED_SCREEN.md`)
- No individual tappable elements inside the block
- On tap: screen slides up with a bottom sheet or page push navigation (match existing UTOPIA nav pattern)

---

### States

| State | Display |
|-------|---------|
| **Loaded** | Shows top headline and update time |
| **Loading** | Shimmer/skeleton on subtitle lines |
| **No internet on first load** | Show "Brief unavailable — check your connection" in subtitle |
| **Stale (>24h old)** | Show "Updated yesterday" instead of time — still display last cached content |
| **Empty** | Hide block entirely if no data has ever loaded |

---

### Visual Style Rules
- Card background: uses `cardBackground` theme token (frosted glass / dark surface — theme dependent)
- Icon container: uses `accentMuted` theme token for background
- Icon color: uses `accentPrimary` theme token
- Title text: uses `textPrimary` theme token
- Subtitle text: uses `textSecondary` theme token
- Update time text: uses `textMuted` theme token
- Border radius: match existing dashboard cards
- Padding: match existing dashboard cards exactly (Daily Note / Reminders reference)

> All color tokens are defined in `03_THEME_INTEGRATION.md`
