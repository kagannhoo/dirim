-- Acil durum kişileri tablosu
-- Supabase Dashboard > SQL Editor'de çalıştırın.

CREATE TABLE IF NOT EXISTS emergency_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  relationship TEXT,
  is_verified BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user_id
  ON emergency_contacts(user_id);

ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own emergency contacts"
  ON emergency_contacts FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own emergency contacts"
  ON emergency_contacts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own emergency contacts"
  ON emergency_contacts FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own emergency contacts"
  ON emergency_contacts FOR DELETE
  USING (auth.uid() = user_id);
