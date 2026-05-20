# UTOPIA — Today's Brief
## 06 — Implementation Checklist

Use this file as the build order. Complete each item before moving to the next. Do not skip ahead.

---

### Phase 1 — Database

- [ ] Create `news_briefs` table in Supabase with schema from `04_DATA_ARCHITECTURE.md`
- [ ] Add index on `(fetched_date, category, is_active)`
- [ ] Enable Row Level Security — read-only for authenticated users, full access for service role only
- [ ] Test: manually insert 2 fake rows and query them from the Flutter app

---

### Phase 2 — Supabase Edge Function

- [ ] Create Edge Function named `fetch-daily-news`
- [ ] Implement RSS fetch for all 6 categories using sources from `04_DATA_ARCHITECTURE.md`
- [ ] Use `rss2json.com` or `NewsData.io` to convert RSS to JSON — pick one and stick to it
- [ ] Filter out articles older than 48 hours before sending to AI
- [ ] Implement AI call per article using prompt from `05_AI_SUMMARIZATION.md`
- [ ] Implement output validation and safe JSON parsing
- [ ] Implement DB insert logic (delete today's rows first, then insert fresh)
- [ ] Test function manually via Supabase dashboard — verify rows appear in DB
- [ ] Set up cron schedule: daily at 00:30 UTC (6:00 AM IST)

---

### Phase 3 — Flutter Data Layer

- [ ] Create `NewsBrief` model with all fields from `04_DATA_ARCHITECTURE.md`
- [ ] Create `NewsBriefRepository` with `getTodaysBriefs()` method
- [ ] Implement local caching using UTOPIA's existing cache mechanism
- [ ] Implement cache-first logic: check cache → fetch if miss → cache result
- [ ] Create state classes: `NewsBriefLoading`, `NewsBriefLoaded`, `NewsBriefError`, `NewsBriefEmpty`
- [ ] Integrate with UTOPIA's existing state management — do not introduce a new library

---

### Phase 4 — Dashboard Block Widget

- [ ] Create `NewsBriefDashboardCard` widget
- [ ] Match layout exactly to existing dashboard cards (Daily Note / Activity reference)
- [ ] Use theme tokens only — no hardcoded colors (see `03_THEME_INTEGRATION.md`)
- [ ] Implement all 4 states: Loaded, Loading (shimmer), Error, Empty (hidden)
- [ ] Wire tap to navigate to News Feed Screen
- [ ] Insert widget into home dashboard in correct position (below Activity, above nav bar)
- [ ] Test in all 8 themes visually

---

### Phase 5 — News Feed Screen

- [ ] Create `NewsBriefScreen` widget / route
- [ ] Implement screen header with title, date, update time
- [ ] Implement horizontal category tab chips with active/inactive states
- [ ] Implement tab switching — instant, no loading between tabs
- [ ] Create `NewsBriefCard` widget with 4 elements: source+time, headline, key fact, summary
- [ ] Cards are NOT tappable — remove any tap gesture or ink splash
- [ ] Implement empty state card per category
- [ ] Implement full-screen error state with retry button
- [ ] Implement shimmer skeleton for initial load (reuse UTOPIA's existing skeleton if available)
- [ ] Independent scroll position per tab
- [ ] Test in all 8 themes visually

---

### Phase 6 — QA

- [ ] Run full theme audit — all 8 themes, both dashboard block and feed screen
- [ ] Test with no internet — verify cache serves stale data correctly
- [ ] Test with cache miss (clear cache, open app) — verify loading state shows correctly
- [ ] Test edge function error — verify app shows error state gracefully
- [ ] Test category with <2 articles — verify empty state shows correctly
- [ ] Test on iQOO Z9s Pro (test device) — check layout, scroll, performance
- [ ] Verify news cards are not tappable
- [ ] Verify no hardcoded color exists anywhere in new code

---

### Definition of Done
- All checklist items above are checked
- Feature works in all 8 themes without visual inconsistency
- No new dependencies introduced (unless absolutely unavoidable)
- No hardcoded colors anywhere
- Edge function runs successfully on schedule and populates DB
- App loads and displays news correctly on cold open and warm open
