#include <SoftwareSerial.h>

SoftwareSerial ch0Serial(10, 11); // ch0: TX on pin 11 -> up counter
SoftwareSerial ch2Serial(12, 13); // ch2: TX on pin 13 -> binary counter (0-15)

uint8_t ch0_upCounter  = 0x00;
uint8_t ch1_constZero  = 0x00;   // stays 0, always
uint8_t ch2_binCounter = 0x00;   // cycles 0-15
uint8_t ch3_hexCounter = 0x00;   // counts up -- shown in hex on ESP32 side
uint8_t ch4_upCounter2 = 0x00;   // second independent up counter

unsigned long lastSend = 0;

void setup() {
  Serial.begin(115200);   // USB debug only
  ch0Serial.begin(9600);  // pin 11
  Serial3.begin(38400);   // pin 14 (hardware TX3)
  ch2Serial.begin(57600); // pin 13
  Serial1.begin(19200);   // pin 18 (hardware TX1)
  Serial2.begin(9600);    // pin 16 (hardware TX2)
}

void loop() {
  if (millis() - lastSend >= 200) {
    lastSend = millis();

    ch0Serial.write(ch0_upCounter);
    Serial3.write(ch1_constZero);
    ch2Serial.write(ch2_binCounter);
    Serial1.write(ch3_hexCounter);
    Serial2.write(ch4_upCounter2);

    ch0_upCounter++;
    // ch1_constZero: never changes
    ch2_binCounter = (ch2_binCounter + 1) & 0x0F;
    ch3_hexCounter++;
    ch4_upCounter2 += 2;
  }
}
