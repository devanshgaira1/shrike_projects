
#include <Shrike.h>
ShrikeFlash fpga;

#define FPGA_RX_PIN 4

uint8_t channelData[5] = {0, 0, 0, 0, 0};
bool expectingData = false;
uint8_t currentChannel = 0;

void setup() {
  Serial.begin(115200);
  delay(1000);

  if (!fpga.begin()) {
    Serial.println("ShrikeFlash init failed!");
    while (1);
  }

  if (!fpga.fileExists("/fpga5ch.bin")) {
    Serial.println("fpga5ch.bin MISSING -- upload it via LittleFS first.");
    while (1);
  }

  Serial.println("Flashing FPGA with fpga5ch.bin...");
  bool flashOk = fpga.flash("/fpga5ch.bin");
  Serial.print("fpga.flash() returned: ");
  Serial.println(flashOk ? "SUCCESS" : "FAILED");
  if (!flashOk) {
    while (1);
  }
  Serial.println("FPGA flash step complete, entering main loop.");

  Serial1.begin(9600, SERIAL_8N1, FPGA_RX_PIN, -1); 
  Serial.println("millis,ch0_up,ch1_zero,ch2_bin4,ch3_hex,ch4_up2");
}

void loop() {
  while (Serial1.available()) {
    uint8_t b = Serial1.read();
    if (!expectingData) {
      if (b <= 4) { currentChannel = b; expectingData = true; }
    } else {
      channelData[currentChannel] = b;
      expectingData = false;
    }
  }

  static unsigned long lastPrint = 0;
  if (millis() - lastPrint >= 100) {
    lastPrint = millis();

    char binStr[5];
    for (int i = 0; i < 4; i++) binStr[i] = ((channelData[2] >> (3 - i)) & 0x01) ? '1' : '0';
    binStr[4] = '\0';

    Serial.printf("%lu,%d,%d,%s,0x%02X,%d\n",
      millis(), channelData[0], channelData[1], binStr, channelData[3], channelData[4]);
  }
}
