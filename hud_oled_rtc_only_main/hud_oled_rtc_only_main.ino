#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <RTClib.h>
#include "Poppins_SemiBold12pt7b.h"  // Custom Poppins font for time
// #include "Poppins_Regular9pt7b.h"  // Custom Poppins font for date/day
#include "Poppins_SemiBold8pt7b.h"
#include "Poppins_SemiBold7pt7b.h"
#include "Poppins_SemiBold6pt7b.h"

// Define separate I2C buses
TwoWire I2C_RTC = TwoWire(0);   // RTC on GPIO 16, 17
TwoWire I2C_OLED = TwoWire(1);  // OLED on GPIO 21, 22

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define SCREEN_ADDRESS 0x3C

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &I2C_OLED, -1);
RTC_DS3231 rtc;

const char* daysOfTheWeek[7] = {
  "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
};

const char* monthsOfTheYear[12] = {
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
};


void setup() {
  Serial.begin(9600);

  // Initialize separate I2C buses
  I2C_RTC.begin(16, 17);     // RTC on I2C bus 0
  I2C_OLED.begin(21, 22);    // OLED on I2C bus 1

  // Attach RTC to its I2C bus
  if (!rtc.begin(&I2C_RTC)) {
    Serial.println("RTC not found");
    while (1);
  }

  // Uncomment to set time
  // rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));

  // Attach OLED to its I2C bus
  if (!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println("OLED not found");
    while (1);
  }

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(10, 32); // Adjusted for custom font baseline
  display.print("Starting...");
  display.display();
  delay(1000);
}

void loop() {
  DateTime now = rtc.now();
  float temperature = rtc.getTemperature(); // Read temperature from DS3231

  int hour = now.hour();
  bool isPM = false;
  if (hour >= 12) {
    isPM = true;
    if (hour > 12) hour -= 12;
  }
  if (hour == 0) hour = 12;

  char timeBuffer[6]; // HH:MM
  sprintf(timeBuffer, "%02d:%02d", hour, now.minute());
  const char* meridian = isPM ? "PM" : "AM";

  char dateBuffer[12];
  sprintf(dateBuffer, "%d %s %02d", now.day(), monthsOfTheYear[now.month() - 1], now.year() % 100);
  const char* weekday = daysOfTheWeek[now.dayOfTheWeek()];

  // Format temperature
  char tempBuffer[12];
 sprintf(tempBuffer, "%d\xB0" "C", (int)round(temperature));

  // Format combined temperature and day
  char topLineBuffer[32];
  sprintf(topLineBuffer, "%s | %s", tempBuffer, weekday);

  display.clearDisplay();

  int16_t x1, y1;
  uint16_t w, h;

  // Temperature and Day display (on top)
  display.setFont(&Poppins_SemiBold6pt7b);
  display.getTextBounds(topLineBuffer, 0, 0, &x1, &y1, &w, &h);
  display.setCursor((SCREEN_WIDTH - w) / 2, 15);
  display.print(topLineBuffer);

  // Time display - middle
  display.setFont(&Poppins_SemiBold12pt7b);
  display.getTextBounds(timeBuffer, 0, 0, &x1, &y1, &w, &h);
  display.setCursor(((SCREEN_WIDTH - w) / 2) - 4, 40);
  display.print(timeBuffer);

  // AM/PM indicator next to time
  display.setFont();
  display.setTextSize(1);
  int timeRight = ((SCREEN_WIDTH - w) / 2) + w + 2;
  display.setCursor(timeRight + 4, 30);  // Aligned to time baseline
  display.print(meridian);

  // Date display - bottom
  display.setFont(&Poppins_SemiBold8pt7b);
  display.getTextBounds(dateBuffer, 0, 0, &x1, &y1, &w, &h);
  display.setCursor((SCREEN_WIDTH - w) / 2, 56);
  display.print(dateBuffer);

  // Temperature is now displayed with the day at the top

  display.setFont(); // Reset font
  display.display();
  delay(1000);
}