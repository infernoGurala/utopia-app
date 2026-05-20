-- Create news_categories table
create table if not exists public.news_categories (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  label text not null,
  display_order integer not null,
  is_active boolean default true,
  keywords text[] not null
);

-- Enable RLS
alter table public.news_categories enable row level security;

-- Policy to allow read access for authenticated users
create policy "Allow read access for authenticated users"
  on public.news_categories
  for select
  to authenticated
  using (true);

-- Grant permissions to authenticated and service_role
grant select on public.news_categories to authenticated;
grant all on public.news_categories to service_role;

-- Insert initial rows
insert into public.news_categories (slug, label, display_order, keywords) values
  ('world', 'World', 1, array['global diplomacy', 'international relations', 'wars', 'treaties', 'UN', 'NATO', 'climate accords', 'humanitarian', 'foreign policy']),
  ('tech', 'Tech', 2, array['gadgets', 'software', 'hardware', 'Apple', 'Google', 'Microsoft', 'Samsung', 'startups', 'cybersecurity', 'robotics', 'semiconductors']),
  ('ai', 'AI', 3, array['artificial intelligence', 'machine learning', 'LLMs', 'OpenAI', 'Anthropic', 'Gemini', 'ChatGPT', 'neural networks', 'AI regulation', 'AI tools']),
  ('science', 'Science', 4, array['space', 'NASA', 'ISRO', 'physics', 'biology', 'medicine', 'research', 'discoveries', 'quantum', 'environment', 'climate science']),
  ('india', 'India', 5, array['Indian government', 'ISRO', 'Indian economy', 'Indian startups', 'Modi', 'Indian sports', 'infrastructure', 'Indian tech']),
  ('movies', 'Movies', 6, array['film releases', 'box office', 'trailers', 'directors', 'OTT', 'Netflix', 'Amazon Prime', 'Disney+', 'awards', 'sequels']),
  ('entertainment', 'Entertainment', 7, array['gaming', 'esports', 'YouTube', 'streaming', 'music industry', 'anime', 'comics', 'Marvel', 'DC', 'celebrity projects']),
  ('social_media', 'Social Media', 8, array['Instagram', 'Twitter', 'X', 'TikTok', 'Meta', 'YouTube policy', 'viral trends', 'platform updates', 'creator economy']),
  ('sports', 'Sports', 9, array['cricket', 'football', 'F1', 'Olympics', 'NBA', 'tennis', 'IPL', 'FIFA', 'athlete records', 'championships']),
  ('politics', 'Politics', 10, array['elections', 'government policy', 'parliament', 'laws', 'international politics', 'diplomatic decisions', 'official statements']),
  ('economy', 'Economy', 11, array['stock market', 'GDP', 'inflation', 'RBI', 'Federal Reserve', 'trade', 'corporate earnings', 'startup funding', 'crypto'])
on conflict (slug) do update set
  label = excluded.label,
  display_order = excluded.display_order,
  keywords = excluded.keywords;
