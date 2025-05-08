import 'dart:async';
import 'dart:math';
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
    try {
      // Check if accessibility service is enabled
      bool isEnabled = await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
      
      print("Starting to listen for navigation data. Accessibility enabled: $isEnabled");
      
      if (!isEnabled) {
        return false;
      }
      
      // Cancel any existing subscription to avoid memory leaks
      if (_subscription != null) {
        await _subscription!.cancel();
        _subscription = null;
      }
      
      // Set up accessibility event listener with proper error handling
      _subscription = FlutterAccessibilityService.accessStream.listen(
        (event) {
          try {
            // Process only Google Maps events to avoid excessive processing
            if (event.packageName == "com.google.android.apps.maps") {
              print("Received Google Maps event text: ${event.text?.toString() ?? 'no text'}");
              print("Event details summary: ${event.toString().substring(0, min(100, event.toString().length))}...");
              
              // Try to process the event data
              if (event.text != null) {
                _processMapData(event);
              }
            }
          } catch (e) {
            print("Error processing accessibility event: $e");
          }
        },
        onError: (error) {
          print("Error in accessibility stream: $error");
        },
        onDone: () {
          print("Accessibility stream closed");
          _isRunning = false;
        },
      );
      
      _isRunning = true;
      return true;
    } catch (e) {
      print("Error starting accessibility service: $e");
      _isRunning = false;
      return false;
    }
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
    try {
      // Try to extract full event details for debugging
      String eventString = event.toString();
      print("Processing full event string: ${eventString.substring(0, min(200, eventString.length))}...");
      
      // Direct extraction from navigation elements using common patterns
      _scanTextFromNavigationUI(eventString);
      
      // Only attempt to process text list if it exists
      if (event.text != null && event.text is List && event.text.isNotEmpty) {
        List<String> textItems = [];
        for (var item in event.text) {
          if (item != null) {
            textItems.add(item.toString());
            print("Text item found: $item");
          }
        }
        
        // Process each text item individually
        for (String item in textItems) {
          _processTextItem(item);
        }
        
        // Also process the combined text
        String nodeText = textItems.join(" ");
        _processTextItem(nodeText);
      } else {
        // Try direct extraction of potential navigation elements
        // Look for properties that might hold navigation information
        try {
          // Extract any properties that might be available based on the event's structure
          String eventDebug = event.toString();
          
          // Check for contentDescription
          if (eventDebug.contains("contentDescription")) {
            int contentStart = eventDebug.indexOf("contentDescription") + "contentDescription".length;
            if (contentStart >= 0) {
              String contentSection = eventDebug.substring(contentStart, min(contentStart + 100, eventDebug.length));
              
              // Try to extract the value - typically in quotes or after a colon
              RegExp contentRegex = RegExp(r'[:=]\s*"([^"]+)"');
              var contentMatch = contentRegex.firstMatch(contentSection);
              if (contentMatch != null && contentMatch.group(1) != null) {
                String contentValue = contentMatch.group(1)!;
                print("Extracted content description: $contentValue");
                _processTextItem(contentValue);
              }
            }
          }
          
          // Look for other useful properties
          List<String> interestingProps = ["text", "label", "value", "hint", "description"];
          for (String prop in interestingProps) {
            if (eventDebug.contains(prop)) {
              int propStart = eventDebug.indexOf(prop) + prop.length;
              if (propStart >= 0) {
                String propSection = eventDebug.substring(propStart, min(propStart + 100, eventDebug.length));
                
                // Try to extract the value
                RegExp propRegex = RegExp(r'[:=]\s*"([^"]+)"');
                var propMatch = propRegex.firstMatch(propSection);
                if (propMatch != null && propMatch.group(1) != null) {
                  String propValue = propMatch.group(1)!;
                  print("Extracted $prop: $propValue");
                  _processTextItem(propValue);
                }
              }
            }
          }
        } catch (e) {
          print("Error extracting properties: $e");
        }
      }
    } catch (e) {
      print("Error processing Maps data: $e");
    }
  }
  
  // Specialized method to extract navigation information from Google Maps UI elements
  void _scanTextFromNavigationUI(String eventString) {
    try {
      // Common navigation instruction patterns in Google Maps
      List<RegExp> patterns = [
        // Direction patterns (various formats)
        RegExp(r'"([^"]*(?:turn left|turn right|continue|head|exit|roundabout|u-turn)[^"]*)"', caseSensitive: false),
        
        // Distance patterns (with units)
        RegExp(r'"([^"]*\d+[^"]*(?:m|km|meters|kilometers|mi|miles|ft|feet)[^"]*)"', caseSensitive: false),
        
        // ETA patterns
        RegExp(r'"([^"]*(?:ETA|arrive|arrival)[^"]*\d+[^"]*(?:min|minute|hour|am|pm)[^"]*)"', caseSensitive: false),
        
        // Street name patterns
        RegExp(r'"([^"]*(?:street|road|avenue|drive|lane|boulevard|highway|freeway|expressway)[^"]*)"', caseSensitive: false),
      ];
      
      // Apply each pattern and collect all matches
      for (RegExp pattern in patterns) {
        Iterable<RegExpMatch> matches = pattern.allMatches(eventString);
        for (RegExpMatch match in matches) {
          if (match.group(1) != null) {
            String text = match.group(1)!;
            print("Extracted UI text: $text");
            _processTextItem(text);
          }
        }
      }
    } catch (e) {
      print("Error scanning navigation UI: $e");
    }
  }
  
  // Process an individual text item from Google Maps
  void _processTextItem(String text) {
    if (text.isEmpty) return;
    
    text = text.toLowerCase();
    
    // Check for navigation instructions
    if (text.contains("turn left") || 
        text.contains("turn right") ||
        text.contains("continue straight") ||
        text.contains("continue on") ||
        text.contains("head") ||
        text.contains("exit") ||
        text.contains("slight left") ||
        text.contains("slight right") ||
        text.contains("sharp left") ||
        text.contains("sharp right") ||
        text.contains("u-turn") ||
        text.contains("roundabout")) {
      String direction = _extractDirection(text);
      print("Extracted direction: $direction from: $text");
      _updateDirection(direction);
    }
    
    // Check for distance information
    else if (text.contains(" m") || 
             text.contains(" km") || 
             text.contains("meters") || 
             text.contains("kilometers") ||
             text.contains("mile") ||
             text.contains("feet") ||
             text.contains("ft")) {
      String distance = _extractDistance(text);
      print("Extracted distance: $distance from: $text");
      _updateDistance(distance);
    }
    
    // Check for ETA information
    else if ((text.contains("arrive") || 
              text.contains("eta") ||
              text.contains("destination") ||
              text.contains("arrival")) && 
             (text.contains("min") || 
              text.contains("hour") ||
              text.contains("am") ||
              text.contains("pm"))) {
      String eta = _extractEta(text);
      print("Extracted ETA: $eta from: $text");
      _updateEta(eta);
    }
  }
  
  // Process content description for navigation instructions
  void _processContentDescription(String description) {
    print("Processing content description: $description");
    
    // Check for direction information
    if (description.contains("turn") || 
        description.contains("continue") || 
        description.contains("head") ||
        description.contains("slight") ||
        description.contains("sharp")) {
      String direction = _extractDirection(description);
      print("Extracted direction from content: $direction");
      _updateDirection(direction);
    }
    
    // Check for distance in content description
    if (description.contains(" m") || 
        description.contains(" km") || 
        description.contains("meter") || 
        description.contains("kilometer") ||
        description.contains("mile") ||
        description.contains("feet") ||
        description.contains("ft")) {
      String distance = _extractDistance(description);
      print("Extracted distance from content: $distance");
      _updateDistance(distance);
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
  
  // Process subnodes from Google Maps event
  void _processSubNodes(dynamic event) {
    try {
      // Extract the subnodes part from the event toString()
      String eventString = event.toString();
      
      // Find text values in quotes that might be navigation instructions
      RegExp textRegExp = RegExp(r'"(.*?)"');
      Iterable<RegExpMatch> matches = textRegExp.allMatches(eventString);
      
      for (RegExpMatch match in matches) {
        if (match.group(1) != null && match.group(1)!.length > 3) {
          String text = match.group(1)!;
          print("Found potential text in event: $text");
          _processTextItem(text);
        }
      }
      
      // Look specifically for navigation patterns in the entire string
      _scanForNavigationPatterns(eventString);
      
    } catch (e) {
      print("Error processing subnodes: $e");
    }
  }
  
  // Scan the event string for navigation patterns
  void _scanForNavigationPatterns(String eventString) {
    try {
      // Search for direction keywords
      RegExp directionRegExp = RegExp(
        r'\b(turn left|turn right|continue|head|slight left|slight right|sharp left|sharp right|u-turn|arrive)\b', 
        caseSensitive: false
      );
      
      RegExp distanceRegExp = RegExp(
        r'\b(\d+(?:\.\d+)?\s*(?:m|km|meter|meters|kilometer|kilometers|mile|miles|ft|feet))\b',
        caseSensitive: false
      );
      
      RegExp etaRegExp = RegExp(
        r'\b((?:eta|arrive|arrival)(?:.+?)(?:\d+[:.]?\d*\s*(?:min|minute|minutes|hour|hours|am|pm)))\b',
        caseSensitive: false
      );
      
      // Check for directions
      Iterable<RegExpMatch> dirMatches = directionRegExp.allMatches(eventString.toLowerCase());
      for (RegExpMatch match in dirMatches) {
        if (match.group(0) != null) {
          String text = match.group(0)!;
          print("Found direction pattern: $text");
          _updateDirection(_extractDirection(text));
        }
      }
      
      // Check for distance
      Iterable<RegExpMatch> distMatches = distanceRegExp.allMatches(eventString.toLowerCase());
      for (RegExpMatch match in distMatches) {
        if (match.group(0) != null) {
          String text = match.group(0)!;
          print("Found distance pattern: $text");
          _updateDistance(text);
        }
      }
      
      // Check for ETA
      Iterable<RegExpMatch> etaMatches = etaRegExp.allMatches(eventString.toLowerCase());
      for (RegExpMatch match in etaMatches) {
        if (match.group(0) != null) {
          String text = match.group(0)!;
          print("Found ETA pattern: $text");
          _updateEta(text);
        }
      }
      
    } catch (e) {
      print("Error scanning for navigation patterns: $e");
    }
  }
  
  // Clean up resources
  void dispose() {
    stopListening();
    _directionController.close();
    _distanceController.close();
    _etaController.close();
  }
} 