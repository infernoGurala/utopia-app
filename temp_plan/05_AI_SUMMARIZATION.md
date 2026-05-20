# UTOPIA — Today's Brief
## 05 — AI Summarization Spec

### Purpose
Each article fetched from RSS is passed to an AI model. The AI is responsible for:
1. Deciding if the article is worth showing
2. Writing a clean headline (if the original is clickbait or unclear)
3. Writing a one-line key fact
4. Writing a short plain-language summary paragraph

---

### AI Model
- Use **Gemini Flash** (low cost, fast, sufficient quality) or the same AI provider already used in UTOPIA's assistant feature — do not introduce a second provider if one already exists
- This runs **server-side only** in the Supabase Edge Function — never client-side

---

### Input to AI (per article)

```
title: {original RSS title}
source: {source name}
description: {RSS description / excerpt — usually 1–3 sentences}
category: {world | tech | economy | sports | culture | india}
```

---

### AI Prompt (System)

```
You are a news editor for a student productivity app. Your job is to process a news article and return a clean, simple summary.

Rules:
- Only include factual, event-based news. Skip opinion pieces, editorials, celebrity gossip, sensational headlines, sponsored content, or anything that does not report a real-world event.
- Write for a general audience — plain English, no jargon, no assumed prior knowledge.
- Be concise. Do not add unnecessary words.
- Never editorialize. Stay neutral.
- The summary must be self-contained. The user will not read the original article.

Return ONLY a JSON object with no explanation, no markdown, no extra text. Exactly this format:

{
  "should_include": true or false,
  "reason_excluded": "reason if should_include is false, else null",
  "headline": "Clean, clear headline. Max 12 words.",
  "key_fact": "The single most important fact from this article. One sentence. Max 20 words.",
  "summary": "2–3 sentence plain-language explanation. What happened. Why it matters. What comes next if relevant."
}
```

---

### AI Prompt (User message)

```
Process this article:

Title: {title}
Source: {source}
Category: {category}
Content: {description}
```

---

### Filtering Rules (should_include = false when)

| Condition | Example |
|-----------|---------|
| Opinion / editorial | "Why I think the economy is failing" |
| Celebrity or entertainment gossip | "Actor spotted at restaurant" |
| Sponsored / promotional | Any article that is clearly an ad |
| Vague / no real event | "Things might change soon in politics" |
| Duplicate of another article already processed in this batch | Same event, same day, same category |
| Article is too old (published >48h ago) | Filter at fetch stage before AI, not here |

---

### Output Validation (in Edge Function)

After receiving AI response:
1. Parse JSON — if parsing fails, skip this article (do not crash)
2. Check `should_include` — if false, discard
3. Validate fields: `headline` ≤ 80 chars, `key_fact` ≤ 150 chars, `summary` ≤ 400 chars
4. If any field exceeds limit, truncate cleanly at sentence boundary
5. If all fields are valid, insert into `news_briefs` table

---

### Cost Management

- AI is called **once per article, once per day** — not per user, not per app open
- Estimated: ~40 articles processed per day (8 articles × 5 categories, with some filtered out)
- At Gemini Flash pricing, this is effectively **free** at this scale
- Never call AI on the client side — all processing is in the Edge Function
