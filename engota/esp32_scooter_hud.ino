/*
 * ESP32 Scooter HUD
 * 
 * This sketch receives navigation data from a smartphone app via Bluetooth
 * and displays it on an OLED screen.
 * 
 * Required Libraries:
 * - BluetoothSerial (by ESP32)
 * - Adafruit SSD1306 (by Adafruit)
 * - Adafruit GFX Library (by Adafruit)
 * 
 * Hardware:
 * - ESP32 development board
 * - SSD1306 OLED display (0.96 inch, 128x64 pixels)
 * - Connections: 
 *   - OLED VCC to ESP32 3.3V
 *   - OLED GND to ESP32 GND
 *   - OLED SCL to ESP32 GPIO22
 *   - OLED SDA to ESP32 GPIO21
 */

#include <BluetoothSerial.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// Check if Bluetooth is available
#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth is not enabled! Please run `make menuconfig` to enable it
#endif

// OLED display settings
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1  // Reset pin # (or -1 if sharing Arduino reset pin)
#define SCREEN_ADDRESS 0x3C

// Bluetooth Serial instance
BluetoothSerial SerialBT;

// OLED display instance
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Data storage
String direction = "NO DATA";
String distance = "NO DATA";
String eta = "NO DATA";

// Bluetooth device name
String deviceName = "ScooterHUD-ESP32";

void setup() {
  // Initialize Serial for debugging
  Serial.begin(115200);
  Serial.println("Starting ScooterHUD...");
  
  // Initialize Bluetooth
  SerialBT.begin(deviceName);
  Serial.println("Bluetooth started, device name: " + deviceName);

  // Initialize OLED
  if(!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println(F("SSD1306 allocation failed"));
    for(;;); // Don't proceed, loop forever
  }
  
  // Initial display setup
  display.clearDisplay();
  display.setTextColor(WHITE);
  display.setTextSize(1);
  
  // Show startup screen
  display.clearDisplay();
  display.setCursor(0, 0);
  display.println("ScooterHUD Ready");
  display.println("Waiting for data...");
  display.display();
}

void loop() {
  // Check if data is available from Bluetooth
  if (SerialBT.available()) {
    String receivedData = SerialBT.readStringUntil('\n');
    Serial.println("Received: " + receivedData);
    
    // Parse the data format: DIRECTION|DISTANCE|ETA
    if (parseData(receivedData)) {
      updateDisplay();
    }
  }
  
  // Small delay to prevent CPU hogging
  delay(100);
}

// Parse the received data format: DIRECTION|DISTANCE|ETA
bool parseData(String data) {
  int firstPipe = data.indexOf('|');
  if (firstPipe == -1) return false;
  
  int secondPipe = data.indexOf('|', firstPipe + 1);
  if (secondPipe == -1) return false;
  
  // Extract the parts
  String newDirection = data.substring(0, firstPipe);
  String newDistance = data.substring(firstPipe + 1, secondPipe);
  String newEta = data.substring(secondPipe + 1);
  
  // Update only if data changed
  bool changed = false;
  if (newDirection != direction) {
    direction = newDirection;
    changed = true;
  }
  
  if (newDistance != distance) {
    distance = newDistance;
    changed = true;
  }
  
  if (newEta != eta) {
    eta = newEta;
    changed = true;
  }
  
  return changed;
}

// Update the OLED display with new data
void updateDisplay() {
  display.clearDisplay();
  
  // Direction (large text at the top)
  display.setTextSize(2);
  display.setCursor(0, 0);
  display.println(direction);
  
  // Divider line
  display.drawLine(0, 20, display.width(), 20, WHITE);
  
  // Distance and ETA in smaller text
  display.setTextSize(1);
  
  // Distance on left
  display.setCursor(0, 25);
  display.println("Distance:");
  display.setCursor(0, 35);
  display.println(distance);
  
  // ETA on right
  display.setCursor(0, 48);
  display.println(eta);
  
  // Update the display
  display.display();
} 