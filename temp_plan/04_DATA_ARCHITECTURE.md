# UTOPIA — Today's Brief
## 04 — Data Architecture

### Architecture Overview

```
[RSS Sources]
     │
     ▼
[Supabase Edge Function — runs at 6:00 AM IST daily]
     │  Fetches raw articles via RSS-to-JSON
     │  Sends each article to AI summarizer
     │  Stores results in Supabase DB
     ▼
[Supabase Database — news_briefs table]
     │
     ▼
[UTOPIA Flutter App]
     │  Reads from Supabase on app open
     │  Caches locally for offline access
     ▼
[Home Dashboard Block + News Feed Screen]
```

---

### News Sources (Hardcoded — No User Control)

| Category | Sources |
|----------|---------|
| World | BBC World, Reuters, AP News |
| Science & Tech | Reuters Tech, BBC Tech, The Verge RSS (factual only) |
| Economy | Reuters Business, BBC Business |
| Sports | BBC Sport, ESPN Headlines |
| Culture | Reuters Arts, BBC Culture |
| India | The Hindu, NDTV, Press Trust of India |

**RSS-to-JSON service:** Use `rss2json.com` free API or `NewsData.io` free tier.
- Fetch top 6–8 articles per category (more than needed, to allow AI filtering)
- Final display: 4–5 per category after filtering

---

### Supabase Database Schema

#### Table: `news_briefs`

| Column | Type | Description |
|--------|------|-------------|
| `id` | `uuid` | Primary key |
| `category` | `text` | One of: world, tech, economy, sports, culture, india |
| `source_name` | `text` | e.g. "BBC", "Reuters" |
| `original_title` | `text` | Raw headline from RSS |
| `headline` | `text` | AI-cleaned headline (if different) |
| `key_fact` | `text` | AI one-line key fact |
| `summary` | `text` | AI short paragraph (2–3 sentences) |
| `published_at` | `timestamptz` | Original article publish time |
| `fetched_date` | `date` | Date this brief was generated (YYYY-MM-DD) |
| `display_order` | `integer` | Order within category (1–5) |
| `is_active` | `boolean` | Whether to show this article today |

#### Index
- Index on `(fetched_date, category, is_active)` for fast daily queries

---

### Supabase Edge Function — Daily Fetch

**Function name:** `fetch-daily-news`

**Schedule:** Every day at 6:00 AM IST (00:30 UTC) via Supabase cron or external cron trigger

**Logic:**
1. For each category, fetch RSS feed from assigned sources
2. For each article, call AI summarization (see `05_AI_SUMMARIZATION.md`)
3. AI returns: `{ headline, key_fact, summary, should_include: boolean }`
4. If `should_include` is false, skip the article
5. Take the top 5 passing articles per category
6. Delete today's existing rows for that category (if re-running)
7. Insert new rows with `fetched_date = today`
8. Mark `is_active = true`

**Error handling:**
- If a source RSS fails, skip that source and continue with others
- If fewer than 2 articles pass filtering for a category, leave that category empty for the day
- Log errors but do not crash — partial data is better than no data

---

### Flutter App — Data Layer

#### Model: `NewsBrief`
Fields: `id`, `category`, `sourceName`, `headline`, `keyFact`, `summary`, `publishedAt`, `displayOrder`

#### Repository: `NewsBriefRepository`
- **Method:** `getTodaysBriefs()` — queries Supabase for `fetched_date = today`, `is_active = true`, ordered by `category` and `display_order`
- Returns a `Map<String, List<NewsBrief>>` keyed by category slug

#### Caching Strategy
- On successful fetch, cache the full result locally using `SharedPreferences` or `Hive` — whichever UTOPIA already uses
- Cache key: `news_briefs_{YYYY-MM-DD}`
- On app open: check if today's cache exists → if yes, use cache (no network call) → if no, fetch from Supabase
- Cache expires: automatically ignored when date changes (next day's open fetches fresh)

#### State Management
- Use whatever state management UTOPIA already uses (Provider / Riverpod / Bloc — do not introduce a new one)
- States: `Loading`, `Loaded(data)`, `Error(message)`, `Empty`

---

### Data Flow Summary

```
App opens
  │
  ├─ Cache exists for today?
  │     YES → Load from cache → Show data
  │     NO  → Fetch from Supabase
  │               │
  │               ├─ Success → Cache it → Show data
  │               └─ Failure → Show error state (use last cache if available)
  │
Dashboard block shows top headline from World category, article #1
User taps → News Feed Screen opens with already-loaded data (no second fetch)
```
