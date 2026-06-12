# Generates supabase/migrations/003_medications.sql
import os

drugs = [
('Parol 500mg', 'Ağrı Kesici', 'Baş ağrısı, hafif ateş', 'Parasetamol', 'Reçetesiz'),
('Arveles 25mg', 'Ağrı Kesici', 'Kas, eklem ve diş ağrısı', 'Deksketoprofen', 'Reçeteli'),
('Majezik 100mg', 'Ağrı Kesici', 'Şiddetli ağrı, migren', 'Flurbiprofen', 'Reçeteli'),
('Novalgin 500mg', 'Ağrı Kesici', 'Yüksek ateş, şiddetli ağrı', 'Metamizol sodyum', 'Reçeteli'),
('Minoset Plus', 'Ağrı Kesici', 'Soğuk algınlığı ağrıları', 'Parasetamol, Kafein', 'Reçetesiz'),
('Nurofen Cold & Flu', 'Soğuk Algınlığı', 'Grip, burun tıkanıklığı, ateş', 'İbuprofen, Psödoefedrin', 'Reçeteli'),
('A-Ferin Kapsül', 'Soğuk Algınlığı', 'Grip, nezle semptomları', 'Parasetamol, Klorfeniramin', 'Reçetesiz'),
('Theraflu Forte', 'Soğuk Algınlığı', 'Şiddetli grip, halsizlik', 'Parasetamol, Fenilefrin', 'Reçetesiz'),
('Tylolhot Poşet', 'Soğuk Algınlığı', 'Grip, boğaz ağrısı', 'Parasetamol, Klorfeniramin', 'Reçetesiz'),
('Katarin Kapsül', 'Soğuk Algınlığı', 'Nezle, öksürük, ateş', 'Parasetamol, Oksolamin', 'Reçetesiz'),
('Lansor 30mg', 'Gastrointestinal', 'Mide yanması, reflü', 'Lansoprazol', 'Reçeteli'),
('Nexium 40mg', 'Gastrointestinal', 'Mide ülseri, asit fazlalığı', 'Esomeprazol', 'Reçeteli'),
('Rennie Çiğneme Tableti', 'Gastrointestinal', 'Mide ekşimesi, hazımsızlık', 'Kalsiyum Karbonat', 'Reçetesiz'),
('Gaviscon Şurup', 'Gastrointestinal', 'Mide yanması, reflü', 'Sodyum Aljinat', 'Reçetesiz'),
('Buscopan 10mg', 'Gastrointestinal', 'Mide ve bağırsak spazmları', 'Hiyosin-N-bütilbromür', 'Reçeteli'),
('Beloc Zok 50mg', 'Kardiyovasküler', 'Yüksek tansiyon, ritim bozukluğu', 'Metoprolol', 'Reçeteli'),
('Coraspin 100mg', 'Kardiyovasküler', 'Kan sulandırıcı, pıhtı önleme', 'Asetilsalisilik asit', 'Reçetesiz'),
('Vasoxen 5mg', 'Kardiyovasküler', 'Hipertansiyon (Tansiyon)', 'Nebivolol', 'Reçeteli'),
('Delix 5mg', 'Kardiyovasküler', 'Hipertansiyon, kalp koruması', 'Ramipril', 'Reçeteli'),
('Plavix 75mg', 'Kardiyovasküler', 'Kalp krizi sonrası pıhtı önleyici', 'Klopidogrel', 'Reçeteli'),
('Matofin 500mg', 'Endokrin', 'Tip 2 Diyabet (Şeker)', 'Metformin', 'Reçeteli'),
('Glifor 1000mg', 'Endokrin', 'Tip 2 Diyabet, insülin direnci', 'Metformin', 'Reçeteli'),
('Euthyrox 50mcg', 'Endokrin', 'Tiroid tembelliği (Hipotiroidi)', 'Levotiroksin', 'Reçeteli'),
('Levotiron 100mcg', 'Endokrin', 'Tiroid hormonu eksikliği', 'Levotiroksin', 'Reçeteli'),
('Diamicron MR 30mg', 'Endokrin', 'Tip 2 Diyabet kan şekeri kontrolü', 'Gliklazid', 'Reçeteli'),
('Ventolin İnhaler', 'Solunum Sistemi', 'Astım, nefes darlığı', 'Salbutamol', 'Reçeteli'),
('Symbicort Turbuhaler', 'Solunum Sistemi', 'Astım ve KOAH', 'Budesonid, Formoterol', 'Reçeteli'),
('Desmont Tablet', 'Solunum Sistemi', 'Alerjik astım, burun tıkanıklığı', 'Montelukast, Desloratadin', 'Reçeteli'),
('Singulair 10mg', 'Solunum Sistemi', 'Astım ataklarını önleme', 'Montelukast', 'Reçeteli'),
('Foster İnhaler', 'Solunum Sistemi', 'Kronik astım ve KOAH', 'Beklometazon, Formoterol', 'Reçeteli'),
('Zyrtec 10mg', 'Alerji', 'Saman nezlesi, kaşıntı, kızarıklık', 'Setirizin', 'Reçetesiz'),
('Aerius 5mg', 'Alerji', 'Alerjik rinit, ürtiker', 'Desloratadin', 'Reçeteli'),
('Allerset 10mg', 'Alerji', 'Göz yaşarması, hapşırma', 'Setirizin', 'Reçetesiz'),
('Crebros 5mg', 'Alerji', 'Mevsimsel alerjiler', 'Levosetirizin', 'Reçeteli'),
('Kestine 20mg', 'Alerji', 'Şiddetli alerjik reaksiyonlar', 'Ebastin', 'Reçeteli'),
('Augmentin 1000mg', 'Antibiyotik', 'Genel bakteriyel enfeksiyonlar', 'Amoksisilin, Klavulanik Asit', 'Reçeteli'),
('Klamoks 1000mg', 'Antibiyotik', 'Solunum yolu enfeksiyonları', 'Amoksisilin, Klavulanik Asit', 'Reçeteli'),
('Macrol 500mg', 'Antibiyotik', 'Boğaz ve bademcik iltihabı', 'Klaritromisin', 'Reçeteli'),
('Cipro 500mg', 'Antibiyotik', 'İdrar yolu ve bağırsak enfeksiyonları', 'Siprofloksasin', 'Reçeteli'),
('Monurol 3g Şase', 'Antibiyotik', 'Tek dozluk idrar yolu enfeksiyonu', 'Fosfomisin', 'Reçeteli'),
('Lustral 50mg', 'Psikiyatri/Nöroloji', 'Depresyon, anksiyete, OKB', 'Sertralin', 'Reçeteli (Kırmızı)'),
('Prozac 20mg', 'Psikiyatri/Nöroloji', 'Depresyon, yeme bozuklukları', 'Fluoksetin', 'Reçeteli (Kırmızı)'),
('Cipralex 10mg', 'Psikiyatri/Nöroloji', 'Panik atak, yaygın anksiyete', 'Essitalopram', 'Reçeteli (Kırmızı)'),
('Xanax 0.5mg', 'Psikiyatri/Nöroloji', 'Şiddetli panik ve kaygı bozukluğu', 'Alprazolam', 'Reçeteli (Yeşil)'),
('Neurontin 600mg', 'Psikiyatri/Nöroloji', 'Sinir ucu ağrısı (Nöropati), Epilepsi', 'Gabapentin', 'Reçeteli (Yeşil)'),
('Fucidin Krem', 'Dermatoloji', 'Cilt enfeksiyonları, iltihaplı sivilce', 'Fusidik asit', 'Reçeteli'),
('Travazol Krem', 'Dermatoloji', 'Mantar ve egzama', 'İzokonazol, Diflukortolon', 'Reçeteli'),
('Bepanthol Onarıcı', 'Dermatoloji', 'Cilt kuruluğu, hafif yanık ve çizikler', 'Dekspantenol', 'Reçetesiz'),
('Terramycin Merhem', 'Dermatoloji', 'Yara, yanık ve göz enfeksiyonları', 'Oksitetrasiklin', 'Reçetesiz'),
('Sudocrem', 'Dermatoloji', 'Pişik, tahriş ve akne izleri', 'Çinko oksit', 'Reçetesiz'),
('Voltaren Krem', 'Kas ve Eklem', 'Kas ezilmesi, burkulma, romatizma', 'Diklofenak', 'Reçetesiz'),
('Muscoril Kapsül', 'Kas ve Eklem', 'Şiddetli kas spazmları', 'Tiyokolşikosid', 'Reçeteli'),
('Fastjel Krem', 'Kas ve Eklem', 'Eklem ağrısı, incinme', 'Ketoprofen', 'Reçetesiz'),
('Dicol Jel', 'Kas ve Eklem', 'Lokal kas ağrıları', 'Diklofenak', 'Reçetesiz'),
('Bengay Krem', 'Kas ve Eklem', 'Kas tutulması, sporcu ağrıları', 'Metil salisilat', 'Reçetesiz'),
('Devit-3 Damla', 'Vitamin/Takviye', 'D vitamini eksikliği, kemik sağlığı', 'Kolekalsiferol', 'Reçetesiz'),
('Benexol B12', 'Vitamin/Takviye', 'Halsizlik, sinir sistemi desteği', 'B1, B6, B12 Vitaminleri', 'Reçetesiz'),
('Ferrum Fort', 'Vitamin/Takviye', 'Demir eksikliği anemisi', 'Demir 3 Hidroksit', 'Reçeteli'),
('Supradyn AllDay', 'Vitamin/Takviye', 'Günlük enerji ve bağışıklık desteği', 'Multivitamin', 'Reçetesiz'),
('Pharmaton Kapsül', 'Vitamin/Takviye', 'Fiziksel ve zihinsel yorgunluk', 'Ginseng, Multivitamin', 'Reçetesiz'),
('Refresh Tears', 'Göz ve Kulak', 'Göz kuruluğu, suni gözyaşı', 'Polivinil alkol', 'Reçetesiz'),
('Siprogut Damla', 'Göz ve Kulak', 'Göz veya kulak enfeksiyonu', 'Siprofloksasin', 'Reçeteli'),
('Tobradex Damla', 'Göz ve Kulak', 'Göz iltihabı ve enfeksiyonu', 'Tobramisin, Deksametazon', 'Reçeteli'),
('Visine Damla', 'Göz ve Kulak', 'Göz kanlanması ve kızarıklığı', 'Tetrizolin', 'Reçetesiz'),
('Illiadin Sprey', 'Göz ve Kulak', 'Şiddetli burun tıkanıklığı', 'Oksimetazolin', 'Reçetesiz'),
('Zovirax Krem', 'Antiviral/Mantar', 'Dudak ve cilt uçukları (Herpes)', 'Asiklovir', 'Reçetesiz'),
('Aklovir Hap', 'Antiviral/Mantar', 'Şiddetli viral enfeksiyonlar, zona', 'Asiklovir', 'Reçeteli'),
('Ketoral Şampuan', 'Antiviral/Mantar', 'Saç derisi mantarı, kepek', 'Ketokonazol', 'Reçetesiz'),
('Zalain Krem', 'Antiviral/Mantar', 'Ayak ve cilt mantarı', 'Sertakonazol', 'Reçeteli'),
('Travocort Krem', 'Antiviral/Mantar', 'Ağır kaşıntılı mantar enfeksiyonları', 'İzokonazol', 'Reçeteli'),
('Uroday Şase', 'Üroloji', 'İdrar yolu enfeksiyonu (Tek doz)', 'Fosfomisin', 'Reçeteli'),
('Pyeloseptyl 50mg', 'Üroloji', 'Kronik idrar yolu enfeksiyonları', 'Nitrofurantoin', 'Reçeteli'),
('Purinol Efervesan', 'Üroloji', 'İdrar yolu temizliği, böbrek taşı engelleme', 'Sodyum sitrat', 'Reçetesiz'),
('Spazmex 30mg', 'Üroloji', 'Aşırı aktif mesane, sık idrara çıkma', 'Trospiyum klorür', 'Reçeteli'),
('Buscopan Plus', 'Üroloji', 'Böbrek sancısı, idrar yolu spazmı', 'Hiyosin, Parasetamol', 'Reçeteli'),
]

def esc(s):
    return s.replace("'", "''")

schema = """-- Dirim: İlaç kataloğu ve İlaçlarım
-- Supabase Dashboard > SQL Editor'de çalıştırın.

CREATE TABLE IF NOT EXISTS medications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  medication_name TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL,
  target_condition TEXT NOT NULL,
  active_ingredient TEXT NOT NULL,
  prescription_type TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_medications_category ON medications(category);

CREATE TABLE IF NOT EXISTS user_medications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  medication_id UUID NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
  custom_dosage TEXT,
  frequency TEXT,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, medication_id)
);

ALTER TABLE health_reminders
  ADD COLUMN IF NOT EXISTS user_medication_id UUID REFERENCES user_medications(id) ON DELETE SET NULL;

ALTER TABLE medications ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_medications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'medications' AND policyname = 'Anyone can read medications') THEN
    CREATE POLICY \"Anyone can read medications\" ON medications FOR SELECT USING (true);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_medications' AND policyname = 'Users view own user_medications') THEN
    CREATE POLICY \"Users view own user_medications\" ON user_medications FOR SELECT USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_medications' AND policyname = 'Users insert own user_medications') THEN
    CREATE POLICY \"Users insert own user_medications\" ON user_medications FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_medications' AND policyname = 'Users update own user_medications') THEN
    CREATE POLICY \"Users update own user_medications\" ON user_medications FOR UPDATE USING (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_medications' AND policyname = 'Users delete own user_medications') THEN
    CREATE POLICY \"Users delete own user_medications\" ON user_medications FOR DELETE USING (auth.uid() = user_id);
  END IF;
END $$;

INSERT INTO medications (medication_name, category, target_condition, active_ingredient, prescription_type) VALUES
"""

vals = [f"  ('{esc(d[0])}', '{esc(d[1])}', '{esc(d[2])}', '{esc(d[3])}', '{esc(d[4])}')" for d in drugs]
footer = "\nON CONFLICT (medication_name) DO NOTHING;\n"

out = os.path.join(os.path.dirname(__file__), '..', 'supabase', 'migrations', '003_medications.sql')
with open(out, 'w', encoding='utf-8') as f:
    f.write(schema)
    f.write(',\n'.join(vals))
    f.write(footer)
print('OK', len(drugs))
