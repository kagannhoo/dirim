-- Dirim: Hatırlatıcılar ve genişletilmiş profil tablosu
-- Supabase Dashboard > SQL Editor'de çalıştırın.

-- ─── users_profile genişletme ───────────────────────────────────────────────
ALTER TABLE users_profile
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS gender TEXT,
  ADD COLUMN IF NOT EXISTS blood_type TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_name TEXT,
  ADD COLUMN IF NOT EXISTS emergency_contact_phone TEXT,
  ADD COLUMN IF NOT EXISTS allergies TEXT,
  ADD COLUMN IF NOT EXISTS chronic_conditions TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT;

-- ─── health_reminders tablosu ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS health_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  reminder_type TEXT NOT NULL DEFAULT 'custom'
    CHECK (reminder_type IN ('medication', 'appointment', 'checkup', 'custom')),
  scheduled_date DATE,
  scheduled_time TIME,
  repeat_days TEXT[] DEFAULT '{}',
  is_recurring BOOLEAN NOT NULL DEFAULT false,
  location TEXT,
  doctor_name TEXT,
  dosage TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  notify_before_minutes INT NOT NULL DEFAULT 30,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_health_reminders_user_id
  ON health_reminders(user_id);

CREATE INDEX IF NOT EXISTS idx_health_reminders_active
  ON health_reminders(user_id, is_active);

-- ─── Row Level Security ─────────────────────────────────────────────────────
ALTER TABLE health_reminders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own reminders"
  ON health_reminders FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own reminders"
  ON health_reminders FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own reminders"
  ON health_reminders FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own reminders"
  ON health_reminders FOR DELETE
  USING (auth.uid() = user_id);

-- users_profile RLS (henüz yoksa)
ALTER TABLE users_profile ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'users_profile' AND policyname = 'Users can view own profile'
  ) THEN
    CREATE POLICY "Users can view own profile"
      ON users_profile FOR SELECT USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'users_profile' AND policyname = 'Users can insert own profile'
  ) THEN
    CREATE POLICY "Users can insert own profile"
      ON users_profile FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'users_profile' AND policyname = 'Users can update own profile'
  ) THEN
    CREATE POLICY "Users can update own profile"
      ON users_profile FOR UPDATE USING (auth.uid() = user_id);
  END IF;
END $$;
