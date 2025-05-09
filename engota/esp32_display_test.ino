#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// Display configuration
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
#define SCREEN_ADDRESS 0x3C

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// Counter for changing display
int counter = 0;
char specialChars[] = {'¥', '£', '€', '¢', '±', '§', '¶', 'µ', 'Ω', '∆'};

void setup() {
  Serial.begin(115200);
  
  // Initialize I2C
  Wire.begin();
  
  // Initialize display
  if(!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println(F("SSD1306 allocation failed"));
    for(;;);
  }
  
  // Initial display clear
  display.clearDisplay();
  display.display();
}

void loop() {
  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  
  // Display counter number
  display.setCursor(0, 0);
  display.print(counter);
  
  // Display some scrambled characters
  display.setCursor(0, 30);
  for(int i = 0; i < 5; i++) {
    display.print(specialChars[random(0, 10)]);
    display.print(" ");
  }
  
  display.display();
  
  // Increment counter
  counter = (counter + 1) % 10;
  
  // Add some random noise effect
  if(random(100) > 50) {
    displayNoise();
  }
  
  delay(1000);
}

void displayNoise() {
  // Display random pixels
  for(int i = 0; i < 50; i++) {
    int x = random(0, SCREEN_WIDTH);
    int y = random(0, SCREEN_HEIGHT);
    display.drawPixel(x, y, SSD1306_WHITE);
  }
  display.display();
  delay(50);
} 