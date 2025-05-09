import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'accessibility_service.dart';
import 'notification_maps_reader.dart';
import 'ui/home_page.dart';

// Simple task handler for foreground service
class SimpleTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    print("Foreground service started");
    // Keep the service alive by sending messages to the main isolate
    if (sendPort != null) {
      sendPort.send('Service started');
    }
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    print("Foreground service event");
    // Handle events - this can be used to communicate with the main app
    if (sendPort != null) {
      sendPort.send('Service event');
    }
  }
  
  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    print("Repeating event");
    // Keep the connection to Google Maps alive by requesting focus periodically
    try {
      // Check and ensure the services are running
      if (sendPort != null) {
        sendPort.send('Keep alive');
      }
    } catch (e) {
      print("Error in repeat event: $e");
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    print("Foreground service destroyed");
    if (sendPort != null) {
      sendPort.send('Service destroyed');
    }
  }

  @override
  void onButtonPressed(String id) {
    if (id == 'stopService') {
      FlutterForegroundTask.stopService();
    }
  }
}

// Simple callback function for foreground task
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SimpleTaskHandler());
}

@pragma('vm:entry-point')
void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize required permissions at startup
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
    Permission.notification,  // Add notification permission
  ].request();
  
  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScooterHUD',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
} 