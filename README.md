# Dirim — Biyometrik Sağlık Takip Uygulaması

Flutter mobil uygulama, ESP32 sensör, Supabase veritabanı ve Python AI sunucusu ile çalışan entegre sağlık takip sistemi.

## Proje Bileşenleri

| Bileşen | Teknoloji | Açıklama |
|---------|-----------|----------|
| Mobil | Flutter / Dart | Dirim Android uygulaması |
| Veritabanı | Supabase | Auth, PostgreSQL, RLS |
| AI Sunucu | Python FastAPI | Yüz analizi, LLM önerileri |
| Donanım | ESP32 + MAX30102 | Nabız / SpO₂ ölçümü |

## Klasör Yapısı

```
dirim/
├── lib/                 # Flutter kaynak kodu
├── esp32/               # ESP32 firmware (.ino)
├── supabase/migrations/ # SQL şemaları
└── assets/              # Logo, görseller
```

## Kurulum (Geliştirici)

### 1. Gizli ayarlar

```bash
# Flutter — Supabase ve varsayılan sunucu adresleri
copy lib\config\app_secrets.example.dart lib\config\app_secrets.dart
# Dosyayi duzenleyin: Supabase URL, anon key, istege bagli ESP/AI adresleri

# Android — HTTP cleartext izinleri (ESP32 / AI sunucu)
copy android\network_security_config.example.xml android\app\src\main\res\xml\network_security_config.xml
# Kendi ESP ve AI sunucu IP adreslerinizi ekleyin

# ESP32 — WiFi ve sabit IP
copy esp32\wifi_config.example.h esp32\wifi_config.h
```

Bu üç dosya `.gitignore` ile korunur; GitHub'a yüklenmez.

### 2. Flutter uygulaması

```bash
flutter pub get
flutter run
```

### 3. ESP32

1. `wifi_config.h` dosyasını oluşturun (yukarıdaki adım)
2. Arduino IDE ile `esp32/dirim_esp32.ino` yükleyin

### 4. Bağlantı ayarları

Uygulama içi **Ayarlar** ekranından ESP32 IP ve AI sunucu URL'si girilebilir. Supabase `app_settings` tablosundan da global AI URL okunabilir.

## Güvenlik

- API anahtarları, sunucu IP'leri ve WiFi bilgileri repoda **tutulmaz**
- Groq API key yalnızca AI sunucusunun `.env` dosyasında olmalıdır
- Supabase anon key client'ta kullanılır; hassas işlemler RLS ile korunur

## Lisans

Bitirme projesi — eğitim amaçlı.
