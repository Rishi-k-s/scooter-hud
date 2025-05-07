import 'dart:async';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';

class GoogleMapsReader {
  static final GoogleMapsReader _instance = GoogleMapsReader._internal();
  
  factory GoogleMapsReader() {
    return _instance;
  }
  
  GoogleMapsReader._internal();
  
  // Stream controllers for navigation data
  final _directionController = StreamController<String>.broadcast();
  final _distanceController = StreamController<String>.broadcast();
  final _etaController = StreamController<String>.broadcast();
  
  // Streams that UI can listen to
  Stream<String> get directionStream => _directionController.stream;
  Stream<String> get distanceStream => _distanceController.stream;
  Stream<String> get etaStream => _etaController.stream;
  
  // Subscription for accessibility events
  StreamSubscription<dynamic>? _subscription;
  
  // Current navigation data
  String _currentDirection = "NO DATA";
  String _currentDistance = "NO DATA";
  String _currentEta = "NO DATA";
  
  // Getters for current values
  String get currentDirection => _currentDirection;
  String get currentDistance => _currentDistance;
  String get currentEta => _currentEta;
  
  bool _isRunning = false;
  bool get isRunning => _isRunning;
  
  // Start listening to accessibility events
  Future<bool> startListening() async {
    // Check if accessibility service is enabled
    bool isEnabled = await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
    
    if (!isEnabled) {
      return false;
    }
    
    if (_subscription != null) {
      await _subscription!.cancel();
    }
    
    _subscription = FlutterAccessibilityService.accessStream.listen((event) {
      // Process only events from Google Maps
      if (event.packageName == "com.google.android.apps.maps") {
        _processMapData(event);
      }
    });
    
    _isRunning = true;
    return true;
  }
  
  // Stop listening to accessibility events
  Future<void> stopListening() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }
    
    // Reset data
    _updateDirection("NO DATA");
    _updateDistance("NO DATA");
    _updateEta("NO DATA");
    
    _isRunning = false;
  }
  
  // Process accessibility event data from Google Maps
  void _processMapData(dynamic event) {
    if (event.text == null || event.text.isEmpty) return;
    
    String nodeText = event.text.join(" ");
    
    // Process direction information
    if (nodeText.contains("turn left") || 
        nodeText.contains("turn right") ||
        nodeText.contains("continue straight") ||
        nodeText.contains("head")) {
      _updateDirection(_extractDirection(nodeText));
    }
    // Process distance information
    else if (nodeText.contains(" m") || 
             nodeText.contains(" km") || 
             nodeText.contains("meters") || 
             nodeText.contains("kilometers")) {
      _updateDistance(_extractDistance(nodeText));
    }
    // Process ETA information
    else if (nodeText.contains("arrive") && 
             (nodeText.contains("min") || nodeText.contains("hour"))) {
      _updateEta(_extractEta(nodeText));
    }
  }
  
  void _updateDirection(String newDirection) {
    _currentDirection = newDirection;
    _directionController.add(newDirection);
  }
  
  void _updateDistance(String newDistance) {
    _currentDistance = newDistance;
    _distanceController.add(newDistance);
  }
  
  void _updateEta(String newEta) {
    _currentEta = newEta;
    _etaController.add(newEta);
  }
  
  String _extractDirection(String text) {
    // Simple extraction logic for directions
    if (text.contains("turn left")) return "LEFT";
    if (text.contains("turn right")) return "RIGHT";
    if (text.contains("continue straight")) return "STRAIGHT";
    if (text.contains("head north")) return "NORTH";
    if (text.contains("head south")) return "SOUTH";
    if (text.contains("head east")) return "EAST";
    if (text.contains("head west")) return "WEST";
    if (text.contains("make a u-turn")) return "U-TURN";
    if (text.contains("destination")) return "ARRIVE";
    return "FOLLOW";
  }
  
  String _extractDistance(String text) {
    // Extract numeric distance with unit (simplified approach)
    final RegExp distancePattern = RegExp(r"(\d+(?:\.\d+)?)\s*(m|km|meters|kilometers)");
    final match = distancePattern.firstMatch(text);
    if (match != null) {
      return "${match.group(1)} ${match.group(2)}";
    }
    return text.split(" ").take(3).join(" "); // Take first 3 words as fallback
  }
  
  String _extractEta(String text) {
    // Extract ETA information (simplified approach)
    final RegExp etaPattern = RegExp(r"arrive.+?(\d+(?:\.\d+)?)\s*(min|minutes|hour|hours)");
    final match = etaPattern.firstMatch(text);
    if (match != null) {
      return "ETA ${match.group(1)} ${match.group(2)}";
    }
    
    // Fallback extraction
    if (text.contains("arrive")) {
      return text.replaceAll("you will arrive", "ETA").split(".")[0];
    }
    return "ETA unknown";
  }
  
  // Clean up resources
  void dispose() {
    stopListening();
    _directionController.close();
    _distanceController.close();
    _etaController.close();
  }
} 