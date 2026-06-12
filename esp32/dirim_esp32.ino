#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "MAX30105.h"
#include "heartRate.h" 
#include <WiFi.h>
#include <WebServer.h>
#include "wifi_config.h"

// --- Wi-Fi ve sabit IP (wifi_config.h — GitHub'a gitmez) ---
IPAddress local_IP(ESP_LOCAL_IP_1, ESP_LOCAL_IP_2, ESP_LOCAL_IP_3, ESP_LOCAL_IP_4);
IPAddress gateway(ESP_GATEWAY_1, ESP_GATEWAY_2, ESP_GATEWAY_3, ESP_GATEWAY_4);
IPAddress subnet(ESP_SUBNET_1, ESP_SUBNET_2, ESP_SUBNET_3, ESP_SUBNET_4);
IPAddress dns(ESP_DNS_1, ESP_DNS_2, ESP_DNS_3, ESP_DNS_4);

WebServer server(80); 

// --- OLED Ayarları ---
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

MAX30105 particleSensor;

// --- Nabız ve SpO2 Değişkenleri ---
const byte RATE_SIZE = 4; 
byte rates[RATE_SIZE]; 
byte rateSpot = 0;
long lastBeat = 0; 
float beatsPerMinute;
int beatAvg = 0;
int spO2 = 0;

// SpO2 AC/DC Filtreleme Değişkenleri
long irMax = 0, irMin = 100000;
long redMax = 0, redMin = 100000;

// Animasyon ve Ekran Zamanlayıcıları
long heartBeatTimer = 0;
unsigned long lastDisplayUpdate = 0; // Ekranı kilitlememek için ekledik

// 8x8 Kalp İkonu (Bitmap)
const unsigned char heartIcon [] PROGMEM = {
  0x66, 0xFF, 0xFF, 0xFF, 0x7E, 0x3C, 0x18, 0x00
};

enum State { EKRAN_BASLANGIC, EKRAN_PARMAK_YOK, EKRAN_BEKLENIYOR, EKRAN_VERI };
State currentState = EKRAN_BASLANGIC;

// --- API Uç Noktası (Flutter'ın veriyi çekeceği yer) ---
void handleVitals() {
  String jsonResponse = "{";
  jsonResponse += "\"bpm\":" + String(beatAvg) + ",";
  jsonResponse += "\"spo2\":" + String(spO2) + ",";
  
  if(currentState == EKRAN_PARMAK_YOK) {
    jsonResponse += "\"status\":\"no_finger\"";
  } else if (currentState == EKRAN_BEKLENIYOR) {
    jsonResponse += "\"status\":\"reading\"";
  } else {
    jsonResponse += "\"status\":\"success\"";
  }
  jsonResponse += "}";

  // Flutter'dan gelen isteklere anında cevap ver
  server.sendHeader("Access-Control-Allow-Origin", "*"); 
  server.send(200, "application/json", jsonResponse);
}

// --- Köşe Çerçeve (HUD) Çizim Fonksiyonu ---
void drawCorners() {
  display.drawLine(0, 0, 15, 0, WHITE);
  display.drawLine(0, 0, 0, 15, WHITE);
  display.drawLine(127, 0, 112, 0, WHITE);
  display.drawLine(127, 0, 127, 15, WHITE);
  display.drawLine(0, 63, 15, 63, WHITE);
  display.drawLine(0, 63, 0, 48, WHITE);
  display.drawLine(127, 63, 112, 63, WHITE);
  display.drawLine(127, 63, 127, 48, WHITE);
}

void setup() {
  Serial.begin(115200);
  Wire.begin(15, 14); // ESP32-CAM I2C

  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("OLED basarisiz!"));
    for(;;);
  }

  display.clearDisplay();
  drawCorners();
  display.setTextSize(1);
  display.setTextColor(WHITE);
  display.setCursor(25, 20);
  display.println("Dirim");
  display.setCursor(20, 40);
  display.println("Wi-Fi Baglaniyor...");
  display.display();

  if (!WiFi.config(local_IP, gateway, subnet, dns)) {
    Serial.println("Sabit IP ayarlanamadi!");
  }
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("\nWi-Fi Baglandi!");
  Serial.print("IP Adresi: ");
  Serial.println(WiFi.localIP());

  server.on("/api/vitals", HTTP_GET, handleVitals);
  server.begin();

  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 bulunamadi!");
    while (1);
  }

  particleSensor.setup(0x1F, 4, 2, 400, 411, 4096); 
  
  display.clearDisplay();
  drawCorners();
  display.setCursor(25, 20);
  display.println("Sistem Hazir");
  display.setCursor(15, 40);
  display.print("IP: ");
  display.println(WiFi.localIP()); 
  display.display();
  delay(3000); 
}

void loop() {
  // 1. ÖNCELİK: Flutter'dan gelen HTTP isteklerine anında cevap ver
  server.handleClient();

  // 2. ÖNCELİK: Sensörü olabildiğince hızlı ve kesintisiz oku
  long irValue = particleSensor.getIR();
  long redValue = particleSensor.getRed();
  
  if (irValue < 50000) {
    currentState = EKRAN_PARMAK_YOK;
    beatAvg = 0; 
    spO2 = 0;
    irMax = 0; irMin = 100000;
    redMax = 0; redMin = 100000;
  } 
  else {
    if (beatAvg == 0) currentState = EKRAN_BEKLENIYOR;

    if (irValue > irMax) irMax = irValue;
    if (irValue < irMin) irMin = irValue;
    if (redValue > redMax) redMax = redValue;
    if (redValue < redMin) redMin = redValue;

    if (checkForBeat(irValue) == true) {
      long delta = millis() - lastBeat;
      lastBeat = millis();
      beatsPerMinute = 60 / (delta / 1000.0);
      
      heartBeatTimer = millis(); 

      if (beatsPerMinute < 255 && beatsPerMinute > 20) {
        rates[rateSpot++] = (byte)beatsPerMinute; 
        rateSpot %= RATE_SIZE;
        beatAvg = 0;
        for (byte x = 0 ; x < RATE_SIZE ; x++) beatAvg += rates[x];
        beatAvg /= RATE_SIZE;
        
        float irAC = (irMax - irMin);
        float irDC = irMin;
        float redAC = (redMax - redMin);
        float redDC = redMin;
        
        if (irDC > 0 && redDC > 0) {
          float R = (redAC / redDC) / (irAC / irDC);
          float spo2Calc = 110.0 - (25.0 * R); 
          
          if (spo2Calc > 100.0) spO2 = 99;
          else if (spo2Calc < 85.0) spO2 = 85; 
          else spO2 = (int)spo2Calc;
        }

        irMax = 0; irMin = 100000;
        redMax = 0; redMin = 100000;
        currentState = EKRAN_VERI; 
      }
    }
  }

  // 3. ÖNCELİK (KİLİDİ ÇÖZDÜĞÜMÜZ YER): Ekranı sadece 50 milisaniyede bir yenile
  if (millis() - lastDisplayUpdate > 50) {
    display.clearDisplay();
    drawCorners();

    switch(currentState) {
      case EKRAN_PARMAK_YOK:
        display.setTextSize(1);
        display.setCursor(20, 22);
        display.println("Parmaginizi");
        display.setCursor(20, 36);
        display.println("Yerlestirin...");
        break;

      case EKRAN_BEKLENIYOR:
        display.setTextSize(1); 
        display.setCursor(30, 28);
        display.println("Olculuyor...");
        display.drawRect(25, 42, 78, 4, WHITE);
        display.fillRect(25, 42, (millis() / 50) % 78, 4, WHITE);
        break;

      case EKRAN_VERI:
        display.setTextSize(1);
        display.setCursor(35, 4);
        display.println("Dirim");
        display.drawLine(20, 14, 108, 14, WHITE); 

        display.setCursor(20, 24);
        display.println("BPM");
        display.setTextSize(2);
        display.setCursor(15, 38);
        display.print(beatAvg);

        display.setTextSize(1);
        display.setCursor(80, 24);
        display.println("SpO2");
        display.setTextSize(2);
        display.setCursor(75, 38);
        display.print("%");
        display.print(spO2);

        if (millis() - heartBeatTimer < 150) {
          display.drawBitmap(60, 42, heartIcon, 8, 8, WHITE);
        } else {
          display.drawPixel(63, 45, WHITE);
          display.drawPixel(64, 45, WHITE);
        }
        break;
    }
    display.display();
    lastDisplayUpdate = millis(); // Sayacı sıfırla
  }
}
