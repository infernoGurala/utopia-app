# UTOPIA — Today's Brief (News Feature)
## Feature Overview

### What This Feature Is
"Today's Brief" is a daily AI-curated news digest embedded in the UTOPIA home dashboard. It gives students a fast, clean snapshot of what's happening in the world — categorized, summarized by AI into plain language, refreshed once per day, and designed to take under 2 minutes to read.

### Core Philosophy
- **No junk.** Only factual, event-based news from hardcoded trusted sources.
- **No infinite scroll.** Each category has exactly 4–5 articles. You read, you're done.
- **No tapping into rabbit holes.** Cards are self-contained. No in-app browser. No external links.
- **Productivity-first.** The user opens UTOPIA, glances at the brief, feels informed, moves on.

### Feature Files in This Spec
| File | Purpose |
|------|---------|
| `00_OVERVIEW.md` | This file — high-level summary |
| `01_UI_DASHBOARD_BLOCK.md` | The dashboard entry block design |
| `02_UI_NEWS_FEED_SCREEN.md` | The full news feed screen design |
| `03_THEME_INTEGRATION.md` | How the feature adapts to all 8 UTOPIA themes |
| `04_DATA_ARCHITECTURE.md` | Backend pipeline, Supabase schema, data flow |
| `05_AI_SUMMARIZATION.md` | AI prompt design, filtering logic, output format |
| `06_IMPLEMENTATION_CHECKLIST.md` | Step-by-step build checklist for the coding agent |

---

### Summary of User Flow
1. User opens UTOPIA home screen
2. Sees "Today's Brief" block at the bottom of the dashboard (where the quote card sits)
3. Block shows the top headline of the day as a teaser
4. User taps the block → full news feed screen slides up
5. News is organized in horizontal category tabs
6. Each tab shows 4–5 AI-summarized cards
7. User reads, switches tabs, closes screen
8. News refreshes automatically at 6:00 AM every day — no manual action needed
