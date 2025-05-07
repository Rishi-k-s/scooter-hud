# 🛴 ScooterHUD

<div align="center">
  
![ScooterHUD Logo](https://img.shields.io/badge/🛴-ScooterHUD-blue?style=for-the-badge)

**Real-time navigation display for electric scooters powered by ESP32**

[![Flutter](https://img.shields.io/badge/Flutter-3.19.0-02569B?style=flat-square&logo=flutter)](https://flutter.dev/)
[![ESP32](https://img.shields.io/badge/ESP32-v4.4.0-E7352C?style=flat-square&logo=espressif)](https://www.espressif.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)
[![Bluetooth](https://img.shields.io/badge/Bluetooth-Ready-0082FC?style=flat-square&logo=bluetooth)](https://flutter.dev/)
[![OLED](https://img.shields.io/badge/OLED-SSD1306-white?style=flat-square)](https://learn.adafruit.com/monochrome-oled-breakouts)

</div>

## 📱 Overview

ScooterHUD is a smart heads-up display system that enhances safety for electric scooter riders by providing real-time navigation data on a handlebar-mounted OLED screen. The system connects an Android phone running Google Maps to an ESP32 microcontroller, extracting turn-by-turn directions and wirelessly sending them to your scooter.

<div align="center">

![System Overview](https://user-images.githubusercontent.com/your-username/sample-image-link.jpg)
<!-- Replace with an actual image link once available -->

</div>

## ✨ Features

- 📲 **Bluetooth Connectivity**: Seamlessly pairs with ESP32 over Bluetooth
- 🧭 **Real-time Navigation**: Displays current directions, distance to next turn, and ETA
- 🔋 **Background Operation**: Continues running while your phone is locked
- 🛠️ **Easy Setup**: Simple one-time configuration
- 🔄 **Auto-reconnect**: Automatically reconnects when back in range
- 📊 **Clean UI**: Modern Flutter interface for the companion app
- 🛡️ **Privacy-first**: Navigation data stays on your device

## 🛠️ Hardware Requirements

- ESP32 development board
- SSD1306 OLED display (0.96 inch, 128x64 pixels)
- Power source (USB power bank or scooter battery with voltage regulator)
- Handlebar mount for the display
- Jumper wires or custom PCB

### Wiring Diagram

```
ESP32 Pin  →  OLED Display
--------------------------
3.3V       →  VCC
GND        →  GND
GPIO22     →  SCL
GPIO21     →  SDA
```

## 📱 App Installation

1. Clone this repository
```bash
git clone https://github.com/yourusername/scooterHUD.git
cd scooterHUD
```

2. Install dependencies
```bash
flutter pub get
```

3. Build and run the app
```bash
flutter run
```

4. Alternatively, download the pre-built APK from the [Releases](https://github.com/yourusername/scooterHUD/releases) page

## 📟 ESP32 Setup

1. Open `esp32_scooter_hud.ino` in the Arduino IDE
2. Install required libraries:
   - BluetoothSerial (by ESP32)
   - Adafruit SSD1306
   - Adafruit GFX Library
3. Connect your ESP32 via USB
4. Upload the sketch
5. Connect the OLED display according to the wiring diagram

## 📖 How to Use

1. Mount the ESP32 and OLED display on your scooter
2. Open the ScooterHUD app on your phone
3. Enable the Accessibility Service when prompted
4. Connect to your ESP32 device via Bluetooth
5. Start the service using the "Start Service" button
6. Open Google Maps and start navigation
7. The app will extract navigation data and send it to your ESP32 display

## 🔄 Data Flow

```
Google Maps → Android Accessibility Service → ScooterHUD App → Bluetooth → ESP32 → OLED Display
```

## 🔧 Troubleshooting

- **Display shows "NO DATA"**: Ensure the service is running and Google Maps navigation is active
- **Can't connect to ESP32**: Check if Bluetooth is enabled and the ESP32 is powered on
- **No updates during navigation**: Make sure the Accessibility Service is enabled and the app has permission to run in the background

## 👨‍💻 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📬 Contact

If you have any questions or feedback, please open an issue on GitHub or contact the maintainer.

---

<div align="center">
  Made with ❤️ for safer scooter rides
</div>
