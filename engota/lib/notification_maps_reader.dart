import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';

class GoogleMapsNotificationReader {
  static final GoogleMapsNotificationReader _instance = GoogleMapsNotificationReader._internal();
  
  factory GoogleMapsNotificationReader() {
    return _instance;
  }
  
  GoogleMapsNotificationReader._internal();
  
  // Stream controllers for navigation data
  final _directionController = StreamController<String>.broadcast();
  final _distanceController = StreamController<String>.broadcast();
  final _etaController = StreamController<String>.broadcast();
  
  // Streams that UI can listen to
  Stream<String> get directionStream => _directionController.stream;
  Stream<String> get distanceStream => _distanceController.stream;
  Stream<String> get etaStream => _etaController.stream;
  
  // Subscription for notification events
  StreamSubscription<ServiceNotificationEvent>? _subscription;
  
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
  
  // Start listening to notification events
  Future<bool> startListening() async {
    try {
      // Check if notification listener permission is enabled
      bool isEnabled = await NotificationListenerService.isPermissionGranted();
      
      log("Starting to listen for Google Maps notifications. Permission enabled: $isEnabled");
      
      if (!isEnabled) {
        // Request permission if not already granted
        isEnabled = await NotificationListenerService.requestPermission();
        if (!isEnabled) {
          return false;
        }
      }
      
      // Cancel any existing subscription to avoid memory leaks
      if (_subscription != null) {
        await _subscription!.cancel();
        _subscription = null;
      }
      
      // Set up notification event listener
      _subscription = NotificationListenerService.notificationsStream.listen(
        (event) {
          try {
            // Process only Google Maps notifications
            if (event.packageName == "com.google.android.apps.maps") {
              log("Received Google Maps notification: ${event.title} - ${event.content}");
              _processMapNotification(event);
            }
          } catch (e) {
            log("Error processing notification event: $e");
          }
        },
        onError: (error) {
          log("Error in notification stream: $error");
        },
        onDone: () {
          log("Notification stream closed");
          _isRunning = false;
        },
      );
      
      _isRunning = true;
      return true;
    } catch (e) {
      log("Error starting notification listener service: $e");
      _isRunning = false;
      return false;
    }
  }
  
  // Stop listening to notification events
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
  
  // Process notification data from Google Maps
  void _processMapNotification(ServiceNotificationEvent event) {
    try {
      // Google Maps navigation notifications contain the next instruction,
      // distance and sometimes ETA information
      final String? title = event.title;
      final String? content = event.content;
      
      log("Processing Google Maps notification - Title: $title, Content: $content");
      
      // Try to get more information from the full notification object
      _tryGetAdditionalInfo(event);
      
      // Reset to default values before processing in case we can't extract new information
      if (_currentDirection == "NO DATA" && _currentDistance == "NO DATA") {
        log("Starting with default values");
      }
      
      if (title != null && content != null) {
        // First, determine if the title contains distance and content contains direction
        // or vice versa, by checking the format of each
        bool titleContainsDistance = _looksLikeDistance(title);
        bool contentContainsDirection = _isDirectionInstruction(content);
        bool titleContainsDirection = _isDirectionInstruction(title);
        bool contentContainsDistance = _looksLikeDistance(content);
        
        log("Analysis - Title contains distance: $titleContainsDistance, Title contains direction: $titleContainsDirection");
        log("Analysis - Content contains distance: $contentContainsDistance, Content contains direction: $contentContainsDirection");
        
        // Case 1: Title contains distance, content contains direction
        if (titleContainsDistance && contentContainsDirection) {
          _updateDistance(title.trim());
          String direction = _extractDirection(content);
          _updateDirection(direction);
          log("Case 1: Title has distance ($title), Content has direction ($direction)");
        }
        // Case 2: Title contains direction, content contains distance (normal case)
        else if (titleContainsDirection && contentContainsDistance) {
          String direction = _extractDirection(title);
          _updateDirection(direction);
          _updateDistance(content.trim());
          log("Case 2: Title has direction ($direction), Content has distance ($content)");
        }
        // Case 3: If we're not sure, try both ways
        else {
          // Try to extract distance from both fields
          String distanceFromTitle = _extractDistance(title);
          String distanceFromContent = _extractDistance(content);
          
          // Try to extract direction using our methods
          String directionFromTitle = _extractDirection(title);
          String directionFromContent = _extractDirection(content);
          
          // If we find a clear distance in title, use it
          if (distanceFromTitle.isNotEmpty && directionFromContent != title.toUpperCase()) {
            _updateDistance(distanceFromTitle);
            _updateDirection(directionFromContent);
            log("Case 3A: Extracted distance from title and direction from content");
          }
          // If we find a clear distance in content, use it
          else if (distanceFromContent.isNotEmpty && directionFromTitle != content.toUpperCase()) {
            _updateDistance(distanceFromContent);
            _updateDirection(directionFromTitle);
            log("Case 3B: Extracted distance from content and direction from title");
          }
          // Otherwise use standard extraction
          else {
            _extractNavigationData(title, content);
          }
        }
        
        // Try to extract ETA from either field if it contains time information
        if (title.toLowerCase().contains("arriving") || 
            title.contains("min") || 
            title.contains("hour")) {
          _extractEtaFromHeader(title);
        }
        
        if (content.toLowerCase().contains("arriving") || 
            content.contains("min") || 
            content.contains("hour")) {
          _extractEtaFromHeader(content);
        }
        
        // Log the current extracted values for debugging
        log("Current values - Direction: $_currentDirection, Distance: $_currentDistance, ETA: $_currentEta");
      } else {
        log("Null title or content in notification");
      }
    } catch (e) {
      log("Error processing Maps notification: $e");
    }
  }
  
  // Try to get additional information from the full notification
  Future<void> _tryGetAdditionalInfo(ServiceNotificationEvent event) async {
    try {
      // Some notification packages might allow getting the full notification object
      // This is a defensive approach in case we can access more data
      if (event.packageName == "com.google.android.apps.maps") {
        log("Trying to extract additional info from Google Maps notification");
        
        // Check if event has any properties we could use to get ETA
        // This is future-proofing for when the package might expose more properties
        try {
          if (event is dynamic) {
            // Try to access potential properties that might have ETA info
            dynamic dynamicEvent = event;
            
            // Check if the raw property might be available
            if (dynamicEvent.toString().contains("raw") || 
                dynamicEvent.toString().contains("extras") ||
                dynamicEvent.toString().contains("subText") ||
                dynamicEvent.toString().contains("summaryText")) {
              log("Notification might contain additional info: ${dynamicEvent.toString()}");
            }
          }
        } catch (e) {
          // Ignore errors in this exploratory code
          log("No additional properties available: $e");
        }
      }
    } catch (e) {
      log("Error getting additional notification info: $e");
    }
  }
  
  // Extract navigation data from notification title and content
  void _extractNavigationData(String title, String content) {
    try {
      // Extract direction from title (typically contains the instruction)
      String direction = _extractDirection(title);
      _updateDirection(direction);
      log("Extracted direction: $direction from title: $title");
      
      // Extract distance and ETA from content
      // Content format variations:
      // "2.5 km · 5 min"
      // "500 m · 2 min"
      // "2.5 km · Arriving at 3:45 PM"
      // "500 m"
      
      // First, try to extract distance
      String distance = _extractDistance(content);
      if (distance.isNotEmpty) {
        _updateDistance(distance);
        log("Extracted distance: $distance from content: $content");
      } else {
        // If no clear distance pattern found, use the whole content if it seems like a distance
        if (_looksLikeDistance(content)) {
          _updateDistance(content.trim());
          log("Content looks like distance: ${content.trim()}");
        }
      }
      
      // Then, try to extract ETA if present in the content
      if (content.contains("·")) {
        // Contains both distance and ETA with a separator
        List<String> parts = content.split("·");
        if (parts.length >= 2) {
          String eta = parts[1].trim();
          
          // Handle different ETA formats
          if (eta.toLowerCase().contains("arriving")) {
            _updateEta(eta.trim()); // Keep the full "Arriving at X:XX" text
            log("Extracted 'arriving' ETA: $eta from content");
          } else if (eta.contains("min") || eta.contains("hour")) {
            // Add "ETA" prefix only if it's a duration
            _updateEta("ETA " + eta);
            log("Extracted time ETA: $eta from content");
          }
        }
      } else if (content.contains("min") || content.contains("hour")) {
        // Content might have both distance and time without a separator
        String timePart = _extractTimePart(content);
        if (timePart.isNotEmpty) {
          _updateEta("ETA " + timePart);
          log("Extracted time part: $timePart from content without separator");
        }
      }
    } catch (e) {
      log("Error extracting navigation data: $e");
    }
  }
  
  // Extract distance from content
  String _extractDistance(String content) {
    // Common distance patterns in Google Maps notifications
    RegExp distancePattern = RegExp(r'(\d+(?:\.\d+)?\s*(?:km|m|mile|mi))');
    var match = distancePattern.firstMatch(content);
    if (match != null) {
      return match.group(0) ?? "";
    }
    return "";
  }
  
  // Check if text looks like a distance value
  bool _looksLikeDistance(String text) {
    text = text.trim().toLowerCase();
    
    // Check for simple distance patterns like "30 m" or "2.5 km"
    if (RegExp(r'^\d+(?:\.\d+)?\s*(?:km|m|mile|mi)$').hasMatch(text)) {
      return true;
    }
    
    // Check for distance value at the start of text
    if (RegExp(r'^\d+(?:\.\d+)?\s*(?:km|m|mile|mi)').hasMatch(text)) {
      return true;
    }
    
    // Check for common distance units
    return text.contains("km") || 
           (text.contains(" m") || text == "m" || text.endsWith(" m")) || 
           text.contains("mile") || 
           text.contains("mi");
  }
  
  // Extract ETA information from the notification header or other text
  void _extractEtaFromHeader(String text) {
    try {
      log("Attempting to extract ETA from text: $text");
      
      // Check for different ETA formats
      if (text.toLowerCase().contains("arriving")) {
        // Format like "Arriving at 3:45 PM"
        _updateEta(text.trim());
        log("Extracted arrival ETA: $text");
      } 
      else if (text.contains("min") || text.contains("hour")) {
        // Format like "10 min" or "1 hour 20 min"
        
        // Check if the text has other information (like distance) that needs to be filtered out
        if (text.contains("·")) {
          // Split by the separator and find the part with time
          List<String> parts = text.split("·");
          for (String part in parts) {
            if (part.contains("min") || part.contains("hour")) {
              _updateEta("ETA " + part.trim());
              log("Extracted time ETA from part: ${part.trim()}");
              return;
            }
          }
        } 
        // If it's just a time without distance
        else if (_containsOnlyTimeInfo(text)) {
          _updateEta("ETA " + text.trim());
          log("Extracted time-only ETA: $text");
        }
        // If it has both distance and time but no separator
        else {
          // Try to extract just the time part
          String timePart = _extractTimePart(text);
          if (timePart.isNotEmpty) {
            _updateEta("ETA " + timePart);
            log("Extracted time part ETA: $timePart from $text");
          }
        }
      }
    } catch (e) {
      log("Error extracting ETA from text: $e");
    }
  }
  
  // Helper to check if text contains only time information
  bool _containsOnlyTimeInfo(String text) {
    text = text.toLowerCase();
    // Check if it contains distance units
    bool hasDistanceUnits = text.contains("km") || text.contains(" m ") || text.contains("mile");
    // If it has time units but no distance units, it's likely only time info
    return (text.contains("min") || text.contains("hour")) && !hasDistanceUnits;
  }
  
  // Helper to extract just the time part from a string containing both distance and time
  String _extractTimePart(String text) {
    // Common patterns for time in navigation notifications
    RegExp timePattern = RegExp(r'(\d+\s*min|\d+\s*hour|\d+\s*hr|\d+\s*h\s*\d+\s*min)');
    var match = timePattern.firstMatch(text);
    if (match != null) {
      return match.group(0) ?? "";
    }
    return "";
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
    text = text.toLowerCase();
    
    // Enhanced extraction logic for directions
    if (text.contains("turn left") || text.contains("slight left") || text.contains("sharp left")) return "LEFT";
    if (text.contains("turn right") || text.contains("slight right") || text.contains("sharp right")) return "RIGHT";
    if (text.contains("continue straight") || text.contains("go straight") || text.contains("continue on")) return "STRAIGHT";
    if (text.contains("head north")) return "NORTH";
    if (text.contains("head south")) return "SOUTH";
    if (text.contains("head east")) return "EAST";
    if (text.contains("head west")) return "WEST";
    if (text.contains("u-turn")) return "U-TURN";
    if (text.contains("roundabout")) return "ROUNDABOUT";
    if (text.contains("exit")) return "EXIT";
    if (text.contains("destination") || text.contains("arrive")) return "ARRIVE";
    
    // Additional common direction patterns
    if (text.startsWith("left")) return "LEFT";
    if (text.startsWith("right")) return "RIGHT";
    if (text.contains("turn left")) return "LEFT";
    if (text.contains("turn right")) return "RIGHT";
    
    // Special case for when the entire text is just "Turn right" or "Turn left"
    if (text.trim() == "turn right") return "RIGHT";
    if (text.trim() == "turn left") return "LEFT";
    
    // If no specific direction detected, use the text as is (truncated if needed)
    if (text.length > 20) {
      return text.substring(0, 20).toUpperCase();
    }
    return text.toUpperCase();
  }
  
  // Helper method to check if the text contains direction instructions
  bool _isDirectionInstruction(String text) {
    text = text.toLowerCase();
    return text.contains("turn") || 
           text.contains("continue") || 
           text.contains("head") || 
           text.contains("u-turn") || 
           text.contains("roundabout") || 
           text.contains("exit") || 
           text.contains("destination") || 
           text.contains("arrive");
  }
  
  // Clean up resources
  void dispose() {
    stopListening();
    _directionController.close();
    _distanceController.close();
    _etaController.close();
  }
}