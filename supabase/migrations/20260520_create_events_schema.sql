-- ── MIGRATION: CREATE EVENTS SCHEMA ──
-- Migration Date: 2026-05-20
-- Description: Sets up the tables for events, registrations, likes, chats, and certificates.

-- Events Table
CREATE TABLE IF NOT EXISTS events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  short_description TEXT NOT NULL,
  full_description TEXT NOT NULL,
  category TEXT NOT NULL,
  tags TEXT[] DEFAULT '{}',
  banner_url TEXT,
  poster_url TEXT,
  date TIMESTAMP WITH TIME ZONE NOT NULL,
  start_time TEXT NOT NULL,
  end_time TEXT NOT NULL,
  venue TEXT NOT NULL,
  participant_limit INTEGER DEFAULT 0,
  participant_count INTEGER DEFAULT 0,
  registration_deadline TIMESTAMP WITH TIME ZONE,
  organizer_uid TEXT NOT NULL,
  organizer_name TEXT NOT NULL,
  conducted_by TEXT NOT NULL,
  contact_numbers TEXT NOT NULL,
  whatsapp_link TEXT,
  participation_link TEXT,
  provides_attendance BOOLEAN DEFAULT false,
  requires_payment BOOLEAN DEFAULT false,
  fee_amount TEXT,
  provides_certificate BOOLEAN DEFAULT false,
  permission_letter_url TEXT,
  status TEXT NOT NULL,
  is_approved BOOLEAN DEFAULT false,
  is_featured BOOLEAN DEFAULT false,
  university_id TEXT,
  view_count INTEGER DEFAULT 0,
  prize_info TEXT,
  requirements TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Event Registrations Table
CREATE TABLE IF NOT EXISTS event_registrations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  user_name TEXT NOT NULL,
  user_email TEXT,
  ticket_id TEXT,
  checked_in BOOLEAN DEFAULT false,
  registered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(event_id, user_id)
);

-- Event Likes Table
CREATE TABLE IF NOT EXISTS event_likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(event_id, user_id)
);

-- Event Chats Table
CREATE TABLE IF NOT EXISTS event_chats (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  user_name TEXT NOT NULL,
  message TEXT NOT NULL,
  is_organizer BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Event Certificates Table
CREATE TABLE IF NOT EXISTS event_certificates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_id UUID REFERENCES events(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  event_title TEXT NOT NULL,
  issuer_name TEXT NOT NULL,
  certificate_url TEXT,
  issued_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Disable Row Level Security (RLS) to allow offline-first cache reads/writes without complex auth policies
ALTER TABLE events DISABLE ROW LEVEL SECURITY;
ALTER TABLE event_registrations DISABLE ROW LEVEL SECURITY;
ALTER TABLE event_likes DISABLE ROW LEVEL SECURITY;
ALTER TABLE event_chats DISABLE ROW LEVEL SECURITY;
ALTER TABLE event_certificates DISABLE ROW LEVEL SECURITY;
