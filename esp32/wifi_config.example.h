// Bu dosyayi wifi_config.h olarak kopyalayin ve kendi ag bilgilerinizi girin.
// wifi_config.h GitHub'a yuklenmez.

#ifndef WIFI_CONFIG_H
#define WIFI_CONFIG_H

const char* WIFI_SSID = "WiFi_ADINIZ";
const char* WIFI_PASSWORD = "WiFi_SIFRENIZ";

// Sabit IP (telefon hotspot aginiza gore duzenleyin)
#define ESP_LOCAL_IP_1 192
#define ESP_LOCAL_IP_2 168
#define ESP_LOCAL_IP_3 1
#define ESP_LOCAL_IP_4 100

#define ESP_GATEWAY_1 192
#define ESP_GATEWAY_2 168
#define ESP_GATEWAY_3 1
#define ESP_GATEWAY_4 1

#define ESP_SUBNET_1 255
#define ESP_SUBNET_2 255
#define ESP_SUBNET_3 255
#define ESP_SUBNET_4 0

#define ESP_DNS_1 192
#define ESP_DNS_2 168
#define ESP_DNS_3 1
#define ESP_DNS_4 1

#endif
