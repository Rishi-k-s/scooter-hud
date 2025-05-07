import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'accessibility_service.dart';

// Simple task handler for foreground service
class SimpleTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    print("Foreground service started");
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    print("Foreground service event");
  }
  
  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    print("Repeating event");
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    print("Foreground service destroyed");
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  // Bluetooth state
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  BluetoothConnection? _connection;
  BluetoothDevice? _selectedDevice;
  List<BluetoothDevice> _pairedDevices = [];
  bool _isConnecting = false;
  bool _isConnected = false;

  // Navigation data
  String _currentDirection = "NO DATA";
  String _currentDistance = "NO DATA";
  String _currentEta = "NO DATA";
  bool _isServiceRunning = false;
  bool _isAccessibilityEnabled = false;
  
  // Maps reader instance
  final GoogleMapsReader _mapsReader = GoogleMapsReader();
  
  // Timer for periodic updates to ESP32
  Timer? _updateTimer;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize in proper order - permissions first, then other components
    _initializeApp();
  }
  
  // Separate asynchronous initialization to ensure correct order
  Future<void> _initializeApp() async {
    // First request permissions
    await _checkPermissions();
    
    // Then initialize Bluetooth
    await _initBluetooth();
    
    // Check accessibility after permissions
    await _checkAccessibilityPermission();
    
    // Initialize foreground task
    _initForegroundTask();
    
    // Setup navigation data listeners
    _setupNavigationListeners();
    
    // Check if service is running
    await _checkServiceStatus();
  }
  
  // Setup the navigation data listeners
  void _setupNavigationListeners() {
    _mapsReader.directionStream.listen((direction) {
      setState(() {
        _currentDirection = direction;
      });
      _sendDataToESP32();
    });
    
    _mapsReader.distanceStream.listen((distance) {
      setState(() {
        _currentDistance = distance;
      });
      _sendDataToESP32();
    });
    
    _mapsReader.etaStream.listen((eta) {
      setState(() {
        _currentEta = eta;
      });
      _sendDataToESP32();
    });
  }
  
  @override
  void dispose() {
    _stopBluetoothConnection();
    _stopService();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBluetoothConnection();
      _checkAccessibilityPermission();
      _checkServiceStatus();
    }
  }

  Future<void> _initBluetooth() async {
    // Get current bluetooth state
    try {
      _bluetoothState = await FlutterBluetoothSerial.instance.state;
      
      // Request to enable Bluetooth if it's disabled
      if (_bluetoothState != BluetoothState.STATE_ON) {
        try {
          await FlutterBluetoothSerial.instance.requestEnable();
        } catch (e) {
          print('Error enabling Bluetooth: $e');
          // Continue with the app even if Bluetooth enabling fails
        }
      }
      
      // Get paired devices
      await _getPairedDevices();
      
      // Listen for Bluetooth state changes
      FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
        setState(() {
          _bluetoothState = state;
        });
        
        if (state == BluetoothState.STATE_OFF) {
          _stopBluetoothConnection();
        } else if (state == BluetoothState.STATE_ON && _selectedDevice != null) {
          _connectToDevice(_selectedDevice!);
        }
      });
    } catch (e) {
      print('Error initializing Bluetooth: $e');
    }
  }
  
  Future<void> _getPairedDevices() async {
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        _pairedDevices = devices;
      });
      
      // Auto-select ESP32 device if previously connected
      final prefs = await SharedPreferences.getInstance();
      String? savedDeviceAddress = prefs.getString('lastDeviceAddress');
      
      if (savedDeviceAddress != null) {
        for (BluetoothDevice device in devices) {
          if (device.address == savedDeviceAddress) {
            setState(() {
              _selectedDevice = device;
            });
            break;
          }
        }
      }
    } catch (ex) {
      print('Error getting paired devices: ${ex.toString()}');
    }
  }
  
  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_isConnected || _isConnecting) {
      return;
    }
    
    setState(() {
      _isConnecting = true;
    });
    
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      
      setState(() {
        _isConnecting = false;
        _isConnected = true;
        _selectedDevice = device;
      });
      
      // Save the device for future connections
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastDeviceAddress', device.address);
      
      // Send a test message
      _sendDataToESP32();
      
      // Start periodic updates to ESP32 (every 2 seconds)
      _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        _sendDataToESP32();
      });
      
      _connection!.input!.listen(null).onDone(() {
        // The connection was closed
        setState(() {
          _isConnected = false;
        });
        _updateTimer?.cancel();
      });
      
    } catch (ex) {
      print('Error connecting to device: ${ex.toString()}');
      setState(() {
        _isConnecting = false;
      });
    }
  }
  
  void _stopBluetoothConnection() {
    _updateTimer?.cancel();
    _connection?.dispose();
    setState(() {
      _isConnected = false;
      _isConnecting = false;
    });
  }
  
  Future<void> _checkBluetoothConnection() async {
    if (_selectedDevice != null && !_isConnected && !_isConnecting && 
        _bluetoothState == BluetoothState.STATE_ON) {
      _connectToDevice(_selectedDevice!);
    }
  }
  
  void _sendDataToESP32() {
    if (_connection != null && _connection!.isConnected) {
      try {
        // Format data for the ESP32 OLED
        // Structure: DIR|DIST|ETA 
        // Example: "LEFT|500 m|ETA 10 min"
        String dataToSend = "$_currentDirection|$_currentDistance|$_currentEta\n";
        _connection!.output.add(Uint8List.fromList(utf8.encode(dataToSend)));
      } catch (e) {
        print('Error sending data: $e');
      }
    }
  }
  
  Future<void> _checkPermissions() async {
    try {
      // Check all required permissions at once instead of making sequential requests
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
      
      // Log the results for debugging
      statuses.forEach((permission, status) {
        print('Permission: $permission, Status: $status');
      });
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }
  
  Future<void> _checkAccessibilityPermission() async {
    bool isEnabled = await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
    setState(() {
      _isAccessibilityEnabled = isEnabled;
    });
  }
  
  Future<void> _requestAccessibilityPermission() async {
    await FlutterAccessibilityService.requestAccessibilityPermission();
    await _checkAccessibilityPermission();
  }
  
  Future<void> _initForegroundTask() async {
    // Initialize foreground task with minimal configuration
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'notification_channel_id',
        channelName: 'ScooterHUD',
        channelDescription: 'Background service for ScooterHUD',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 1000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWifiLock: false,
      ),
    );
  }
  
  Future<void> _checkServiceStatus() async {
    bool isRunning = await FlutterForegroundTask.isRunningService;
    setState(() {
      _isServiceRunning = isRunning;
    });
  }
  
  Future<void> _startService() async {
    if (!_isAccessibilityEnabled) {
      await _requestAccessibilityPermission();
      if (!_isAccessibilityEnabled) {
        return;
      }
    }
    
    bool mapsStarted = await _mapsReader.startListening();
    
    try {
      // Start the foreground service with minimal configuration
      await FlutterForegroundTask.startService(
        notificationTitle: 'ScooterHUD Running',
        notificationText: 'Monitoring Maps navigation',
        callback: startCallback,
      );
    } catch (e) {
      print('Error starting foreground service: $e');
      // Continue even if foreground service fails
    }
    
    if (mapsStarted) {
      setState(() {
        _isServiceRunning = true;
        _currentDirection = _mapsReader.currentDirection;
        _currentDistance = _mapsReader.currentDistance;
        _currentEta = _mapsReader.currentEta;
      });
      
      // Send initial data
      _sendDataToESP32();
    }
  }
  
  void _stopService() async {
    _mapsReader.stopListening();
    
    try {
      await FlutterForegroundTask.stopService();
    } catch (e) {
      print('Error stopping foreground service: $e');
      // Continue even if stopping the service fails
    }
    
    setState(() {
      _isServiceRunning = false;
      _currentDirection = "NO DATA";
      _currentDistance = "NO DATA";
      _currentEta = "NO DATA";
    });
    
    // Send updated (empty) data
    _sendDataToESP32();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ScooterHUD Controller'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Service Status',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isServiceRunning ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isServiceRunning ? 'RUNNING' : 'STOPPED',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Accessibility Service:'),
                        const SizedBox(width: 8),
                        Text(
                          _isAccessibilityEnabled ? 'Enabled' : 'Disabled',
                          style: TextStyle(
                            color: _isAccessibilityEnabled ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isServiceRunning ? _stopService : _startService,
                      child: Text(_isServiceRunning ? 'Stop Service' : 'Start Service'),
                    ),
                    if (!_isAccessibilityEnabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton(
                          onPressed: _requestAccessibilityPermission,
                          child: const Text('Enable Accessibility Service'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Bluetooth connection card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ESP32 Connection',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isConnected ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isConnected ? 'CONNECTED' : 'DISCONNECTED',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<BluetoothDevice>(
                      decoration: const InputDecoration(
                        labelText: 'Select ESP32 Device',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedDevice,
                      items: _pairedDevices.map((device) {
                        return DropdownMenuItem<BluetoothDevice>(
                          value: device,
                          child: Text(device.name ?? "Unknown Device"),
                        );
                      }).toList(),
                      onChanged: _isConnecting ? null : (device) {
                        setState(() {
                          _selectedDevice = device;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _isConnecting || _selectedDevice == null
                              ? null
                              : (_isConnected
                                  ? _stopBluetoothConnection
                                  : () => _connectToDevice(_selectedDevice!)),
                          child: Text(_isConnecting
                              ? 'Connecting...'
                              : (_isConnected
                                  ? 'Disconnect'
                                  : 'Connect')),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            // Refresh paired devices list
                            await _getPairedDevices();
                          },
                          child: const Text('Refresh Devices'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Navigation data card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Navigation Data',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Direction',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentDirection,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        // Distance
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Distance',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentDistance,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // ETA
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ETA',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentEta,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'How to Use',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Enable the Accessibility Service',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('This allows the app to read navigation data from Google Maps.'),
                    SizedBox(height: 4),
                    Text(
                      '2. Connect to your ESP32',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Select your ESP32 device from the dropdown and connect.'),
                    SizedBox(height: 4),
                    Text(
                      '3. Start the Service',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Click "Start Service" to begin monitoring Google Maps.'),
                    SizedBox(height: 4),
                    Text(
                      '4. Start Navigation in Google Maps',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('The app will automatically extract and send direction data to your ESP32.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 