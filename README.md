# 🛴 Engota

<div align="center">
  
![Engota Logo](https://img.shields.io/badge/🛴-Engota-blue?style=for-the-badge)

**Real-time Navigation & HUD System for Electric Scooters**

[![Flutter](https://img.shields.io/badge/Flutter-3.19.0-02569B?style=flat-square&logo=flutter)](https://flutter.dev/)
[![ESP32](https://img.shields.io/badge/ESP32-v4.4.0-E7352C?style=flat-square&logo=espressif)](https://www.espressif.com/)
[![OLED](https://img.shields.io/badge/OLED-SSD1306-white?style=flat-square)](https://learn.adafruit.com/monochrome-oled-breakouts)
[![RTC](https://img.shields.io/badge/RTC-DS3231-teal?style=flat-square)](https://www.adafruit.com/product/3013)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

</div>

## 📱 Overview

Engota is a smart heads-up display system that enhances the riding experience for electric scooter enthusiasts. The system combines a handlebar-mounted OLED display with an ESP32 microcontroller to provide:

- Real-time clock with temperature display
- Turn-by-turn navigation from Google Maps (via companion app)
- Clean, modern UI with custom fonts
- Multiple display modes

The system consists of hardware components (ESP32 + OLED + RTC) and a Flutter-based companion app that extracts navigation data from Google Maps.

<div align="center">

![System Demo](https://dummyimage.com/800x400/000/ffffff&text=Demo+coming+soon)
<!-- Replace with actual image once available -->

</div>

## ✨ Components

This repository contains multiple project components:

- **hud_main**: The complete firmware with all features
- **hud_oled_rtc_only_main**: Clock-only mode (no navigation) 
- **engota**: Flutter companion app for extracting Google Maps data
- **display_test**: Test sketch for OLED display
- **ds3231_rtc_test**: Test sketch for DS3231 RTC module
- **i2c_finder**: Utility to find I2C device addresses

## 🛠️ Hardware Requirements

- ESP32 development board (ESP32-WROOM or ESP32-WROVER)
- SSD1306 OLED display (0.96", 128x64 resolution)
- DS3231 RTC module
- 3.3V power source
- Waterproof enclosure
- Handlebar mount

### Wiring Diagram

```
ESP32 Pin  →  OLED Display
--------------------------
3.3V       →  VCC
GND        →  GND
GPIO21     →  SDA
GPIO22     →  SCL

ESP32 Pin  →  DS3231 RTC
--------------------------
3.3V       →  VCC
GND        →  GND
GPIO16     →  SDA
GPIO17     →  SCL
```

## 🔧 Hardware Setup

1. Connect the OLED display and RTC module as shown in the wiring diagram
2. Power the ESP32 via USB or external power source
3. Install in a suitable enclosure
4. Mount to your scooter handlebars

## 💻 Firmware Installation

### Prerequisites

- [Arduino IDE](https://www.arduino.cc/en/software)
- ESP32 board support package
- Required libraries:
  - Adafruit GFX
  - Adafruit SSD1306
  - RTClib
  - Wire

### Installation Steps

1. Clone this repository
```bash
git clone https://github.com/Rishi-k-s/engota.git
cd engota
```

2. Open Arduino IDE and select your ESP32 board

3. Install required libraries via Library Manager

4. Open the desired sketch:
   - `hud_main/hud_main.ino` for full functionality
   - `hud_oled_rtc_only_main/hud_oled_rtc_only_main.ino` for clock-only mode

5. Connect your ESP32 via USB

6. Upload the sketch

## 📱 Flutter App Setup

The companion app extracts navigation data from Google Maps using Android's Accessibility Services.

### Features

- Bluetooth connectivity to ESP32
- Background operation
- Google Maps integration
- Automatic reconnection
- Clean, modern UI

### Installation

1. Navigate to the app directory
```bash
cd engota
```

2. Install dependencies
```bash
flutter pub get
```

3. Build and run the app
```bash
flutter run
```

4. Follow on-screen instructions to connect to your Engota device

## 📊 Modes and Features

### Clock Mode

- Digital time display (12-hour format)
- Date display
- Day of week
- Ambient temperature (from DS3231)
- Custom Poppins font for improved readability

### Navigation Mode (With Companion App)

- Turn-by-turn directions
- Distance to next turn
- ETA
- Street names
- Direction arrows

## 🔄 How It Works

1. The ESP32 runs independently showing time, date, and temperature
2. When paired with the companion app, it receives navigation data
3. The OLED display updates with the latest information
4. The system uses multiple I2C buses to avoid conflicts between components

```
Companion App → Bluetooth → ESP32 → Display
              ↑
Google Maps navigation
```

## 🛠️ Customization

- Edit the display layout in the `.ino` files
- Modify fonts in the header files
- Adjust update frequency and display contrast

## 📬 Troubleshooting

- **Display not working**: Check I2C connections and addresses
- **Time incorrect**: Set the RTC time using the commented code in setup()
- **Bluetooth connection issues**: Ensure power supply is stable

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

<div align="center">
  Made with ❤️ by Rishi
</div> 