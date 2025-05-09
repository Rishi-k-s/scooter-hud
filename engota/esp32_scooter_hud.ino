#include <SPI.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "BluetoothSerial.h"

// Check if Bluetooth is available
#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth is not enabled! Please run `make menuconfig` to enable it
#endif

// OLED display settings
#define SCREEN_WIDTH 128    // OLED display width, in pixels
#define SCREEN_HEIGHT 64    // OLED display height, in pixels
#define OLED_RESET     -1   // Reset pin # (or -1 if sharing Arduino reset pin)
#define SCREEN_ADDRESS 0x3C // I2C address (typical: 0x3D or 0x3C)

// Bluetooth Serial instance
BluetoothSerial SerialBT;

// OLED display instance
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Variables to store navigation data
String direction = "NO DATA";
String distance = "NO DATA";
String eta = "NO DATA";

void setup() {
  // Initialize Serial for debugging
  Serial.begin(115200);
  
  // Initialize Bluetooth with device name
  SerialBT.begin("ESP32_ScooterHUD");
  Serial.println("Bluetooth device started, waiting for connections...");
  
  // Initialize the OLED display
  if(!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println(F("SSD1306 allocation failed"));
    for(;;); // Don't proceed, loop forever
  }
  
  // Initial display setup
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println(F("ScooterHUD Ready"));
  display.println(F("Waiting for data..."));
  display.display();
}

void loop() {
  // Check if there's data available from Bluetooth
  if (SerialBT.available()) {
    // Read the incoming data
    String data = SerialBT.readStringUntil('\n');
    Serial.println("Received: " + data);
    
    // Parse the data - format: DISTANCE|DIRECTION|ETA
    int firstSeparator = data.indexOf('|');
    int secondSeparator = data.lastIndexOf('|');
    
    if (firstSeparator != -1 && secondSeparator != -1 && firstSeparator != secondSeparator) {
      distance = data.substring(0, firstSeparator);
      direction = data.substring(firstSeparator + 1, secondSeparator);
      eta = data.substring(secondSeparator + 1);
      
      // Clean up empty or "NO DATA" values
      if (distance.length() == 0 || distance == "NO DATA") distance = "---";
      if (direction.length() == 0 || direction == "NO DATA") direction = "---";
      if (eta.length() == 0 || eta == "NO DATA") eta = "---";
      
      // Debug print
      Serial.println("Parsed - Distance: " + distance);
      Serial.println("Parsed - Direction: " + direction);
      Serial.println("Parsed - ETA: " + eta);
      
      // Update the display
      updateDisplay();
    }
  }
  
  // Small delay to avoid overwhelming the CPU
  delay(10);
}

void updateDisplay() {
  display.clearDisplay();
  
  // Draw direction information (larger text)
  display.setTextSize(2);
  display.setCursor(0, 0);
  if (direction.length() > 10) {
    display.setTextSize(1);  // Smaller text for long directions
  }
  display.println(direction);
  
  // Draw a line separator
  display.drawLine(0, 21, display.width(), 21, SSD1306_WHITE);
  
  // Draw distance information
  display.setTextSize(1);
  display.setCursor(0, 25);
  display.print(F("Distance: "));
  display.println(distance);
  
  // Draw ETA information
  display.setCursor(0, 40);
  display.print(F("ETA: "));
  display.println(eta);
  
  // Show direction indicator
  String dir = direction;
  dir.toUpperCase();
  if (dir.indexOf("LEFT") != -1) {
    drawLeftArrow();
  } else if (dir.indexOf("RIGHT") != -1) {
    drawRightArrow();
  } else if (dir.indexOf("STRAIGHT") != -1 || dir.indexOf("CONTINUE") != -1) {
    drawStraightArrow();
  } else if (dir.indexOf("SOUTHWEST") != -1) {
    drawSouthwestArrow();
  }
  
  // Update the display
  display.display();
}

void drawLeftArrow() {
  // Draw left arrow icon in bottom right corner
  int x = 100;
  int y = 45;
  display.fillTriangle(x, y, x+12, y-10, x+12, y+10, SSD1306_WHITE);
}

void drawRightArrow() {
  // Draw right arrow icon in bottom right corner
  int x = 112;
  int y = 45;
  display.fillTriangle(x, y, x-12, y-10, x-12, y+10, SSD1306_WHITE);
}

void drawStraightArrow() {
  // Draw up arrow icon in bottom right corner
  int x = 106;
  int y = 40;
  display.fillTriangle(x, y, x-8, y+12, x+8, y+12, SSD1306_WHITE);
}

void drawSouthwestArrow() {
  int x = 106;
  int y = 45;
  // Draw a diagonal arrow pointing southwest
  display.fillTriangle(x, y, x-8, y-8, x+8, y+8, SSD1306_WHITE);
}