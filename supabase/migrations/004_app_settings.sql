-- Global uygulama ayarları (AI sunucusu URL'si tüm kullanıcılar için tek yerden güncellenir)
CREATE TABLE IF NOT EXISTS app_settings (
  id text PRIMARY KEY DEFAULT 'global',
  ai_server_url text,
  updated_at timestamptz DEFAULT now()
);

-- ai_server_url degerini Supabase Dashboard uzerinden kendi sunucu adresinizle guncelleyin.
INSERT INTO app_settings (id, ai_server_url)
VALUES ('global', NULL)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Herkes okuyabilir (sadece public URL, gizli anahtar yok)
CREATE POLICY "app_settings_read" ON app_settings
  FOR SELECT USING (true);

-- Sadece giriş yapmış kullanıcılar güncelleyebilir (geliştirme kolaylığı)
CREATE POLICY "app_settings_update" ON app_settings
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "app_settings_insert" ON app_settings
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
