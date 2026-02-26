import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../services/ai_service.dart';

class ErrorMessage {
  final String filePath;
  final int line;
  final int column;
  final String errorMessage;
  final List<String> contextLines;
  final DateTime timestamp;

  ErrorMessage({
    required this.filePath,
    required this.line,
    required this.column,
    required this.errorMessage,
    required this.contextLines,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'line': line,
        'column': column,
        'errorMessage': errorMessage,
        'contextLines': contextLines,
        'timestamp': timestamp.toIso8601String(),
      };
}

class TerminalService {
  // SINGLETON PATTERN - Ensures single instance across entire app
  static final TerminalService _instance = TerminalService._internal();
  factory TerminalService() => _instance;
  TerminalService._internal(); // Private constructor

  Process? _flutterProcess;
  bool _isMonitoring = false;
  String? _projectRoot; // Configurable project root
  final StreamController<ErrorMessage> _errorController = StreamController<ErrorMessage>.broadcast();
  final StreamController<String> _logController = StreamController<String>.broadcast();
  final List<String> _recentLogs = [];
  static const int _maxLogLines = 50;

  // AI Service instance for autonomous fixes
  final AiService _aiService = AiService();

  // Stream controller for AI fix notifications
  final StreamController<Map<String, dynamic>> _aiFixController = StreamController<Map<String, dynamic>>.broadcast();

  // Stream controller for Android errors from ADB Bridge
  final StreamController<Map<String, dynamic>> _androidErrorController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get aiFixStream => _aiFixController.stream;
  Stream<Map<String, dynamic>> get androidErrorStream => _androidErrorController.stream;

  bool get isMonitoring => _isMonitoring;
  Stream<ErrorMessage> get errorStream => _errorController.stream;
  Stream<String> get logStream => _logController.stream;
  List<String> get recentLogs => List.unmodifiable(_recentLogs);
  String? get projectRoot => _projectRoot; // NEW: Getter for project root

  // Flutter stack trace regex: #0      main (package:name/file.dart:line:column)
  final RegExp _stackTraceRegex = RegExp(
    r'#\d+\s+.*?\(package:([a-zA-Z0-9_]+)\/([a-zA-Z0-9_\/]+\.dart):(\d+):(\d+)\)?',
    caseSensitive: false,
  );

  // Error detection patterns
  final List<RegExp> _errorPatterns = [
    RegExp(r'Exception:|Error:|Failed assertion', caseSensitive: false),
    RegExp(r'Null check operator used on a null value', caseSensitive: false),
    RegExp(r'Unhandled Exception', caseSensitive: false),
    RegExp(r'TypeError|RangeError|ArgumentError', caseSensitive: false),
  ];

  // Build/Compilation error patterns
  final RegExp _compilationErrorRegex = RegExp(r'lib/([\w/]+\.dart):(\d+):(\d+): Error:');

  // Windows MSBuild error format: lib/main.dart(6,70): error G67247B7E: Expected ';'
  final RegExp _windowsBuildErrorRegex = RegExp(r'([\w/]+\.dart)\((\d+),(\d+)\): error [\w\d]+: (.+)');

  // Standard Dart build error format: lib/main.dart:6:70: Error: Expected ';'
  final RegExp _dartBuildErrorRegex = RegExp(r'([\w/]+\.dart):(\d+):(\d+): Error: (.+)');

  // Additional build error patterns
  final RegExp _uriErrorRegex = RegExp(r"Target of URI doesn't exist: 'package:([\w/]+\.dart)'");
  final RegExp _pubspecErrorRegex = RegExp(r"Error on line (\d+), column (\d+) of pubspec\.yaml");

  // UI overflow warning pattern: A RenderFlex overflowed by 42 pixels on the right.
  final RegExp _overflowRegex = RegExp(r'A RenderFlex overflowed by (\d+) pixels on the (.+)\.');

  // Missing asset pattern: Unable to load asset: assets/images/logo.png
  final RegExp _assetRegex = RegExp(r'Unable to load asset: (.+)');

  // Cooldown mechanism to prevent repeated error detection after fixes
  bool _isCooldownActive = false;

  // FIRST-ERROR-ONLY LOCK: Prevents error bombardment when build fails
  bool _isLockedForFixing = false;

  // Error deduplication to prevent spam notifications
  String? _lastErrorLocation;
  Timer? _errorResetTimer;

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    try {
      print('Starting Flutter process monitoring...');

      // Start flutter run process - use full path since flutter may not be in PATH
      final flutterPath = _findFlutterExecutable();
      _flutterProcess = await Process.start(
        flutterPath,
        ['run', '--device-id=windows'], // Specify Windows desktop device
        workingDirectory: _findFlutterProjectRoot(),
        runInShell: true,
      );

      _isMonitoring = true;
      print('Flutter process started. PID: ${_flutterProcess!.pid}');

      // Listen to stdout
      _flutterProcess!.stdout.transform(utf8.decoder).transform(LineSplitter()).listen(
        (line) {
          print('STDOUT: $line'); // Debug logging
          _addToLog(line);
          _checkForErrors(line);
        },
        onError: (error) {
          print('Stdout error: $error');
        },
      );

      // Listen to stderr
      _flutterProcess!.stderr.transform(utf8.decoder).transform(LineSplitter()).listen(
        (line) {
          print('STDERR: $line'); // Debug logging
          _addToLog('[ERROR] $line');
          _checkForErrors(line);
          _checkForBuildErrors(line); // Specifically check for Windows build errors in STDERR
        },
        onError: (error) {
          print('Stderr error: $error');
        },
      );

      // Monitor process exit - detect build failures
      _flutterProcess!.exitCode.then((code) {
        print('Flutter process exited with code: $code');
        _isMonitoring = false;

        // If exit code is non-zero, it indicates a build failure
        if (code != 0) {
          print('🚨 BUILD FAILED (Exit code $code). Analyzing build failure...');
          _analyzeBuildFailure();
        }
      });

    } catch (e) {
      print('Failed to start Flutter monitoring: $e');
      _isMonitoring = false;
      rethrow;
    }
  }

  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    print('Stopping Flutter process monitoring...');
    _flutterProcess?.kill();
    _flutterProcess = null;
    _isMonitoring = false;
  }

  void _addToLog(String line) {
    _recentLogs.add(line);
    if (_recentLogs.length > _maxLogLines) {
      _recentLogs.removeAt(0);
    }
    _logController.add(line);
  }

  void _checkForErrors(String line) {
    // SKIP EVERYTHING during cooldown to prevent repeated error detection
    if (_isCooldownActive) return;

    // Check for RenderFlex overflow warnings (UI issues)
    final overflowMatch = _overflowRegex.firstMatch(line);
    if (overflowMatch != null) {
      final pixels = overflowMatch.group(1)!;
      final side = overflowMatch.group(2)!;
      print('⚠️ UI OVERFLOW DETECTED: $pixels pixels on $side');
      _onOverflowWarningDetected(pixels, side);
      return; // Don't process as error
    }

    // Check for missing asset errors
    final assetMatch = _assetRegex.firstMatch(line);
    if (assetMatch != null) {
      final assetPath = assetMatch.group(1)!;
      print('📁 MISSING ASSET DETECTED: $assetPath');
      _onAssetErrorDetected(assetPath);
      return; // Don't process as error
    }

    // Check for compilation errors (syntax/typos)
    final compMatch = _compilationErrorRegex.firstMatch(line);
    if (compMatch != null) {
      print('🛠️ COMPILATION ERROR DETECTED!');
      final filePath = compMatch.group(1)!;
      final lineNum = int.parse(compMatch.group(2)!);

      // Convert to absolute path
      final projectPath = _findFlutterProjectRoot();
      final absolutePath = "$projectPath\\$filePath";

      // Extract error message
      final errorMessage = line.substring(line.indexOf('Error:')).trim();

      _onCompilationErrorDetected(absolutePath, lineNum, errorMessage);
      return; // Don't process as runtime error
    }

    // Check for runtime error patterns
    bool isErrorLine = _errorPatterns.any((pattern) => pattern.hasMatch(line));
    print('Checking line for errors: "$line" -> isError: $isErrorLine');

    // Always check for stack traces in case they come before/after error lines
    _parseStackTrace([line]);

    if (isErrorLine) {
      print('ERROR DETECTED! Processing...');
      // Store error state for when we find the stack trace
      _hasPendingError = true;
      _pendingErrorLine = line;
    }
  }

  bool _hasPendingError = false;
  String? _pendingErrorLine;

  void _parseStackTrace(List<String> lines) {
    for (final line in lines) {
      print('Testing regex on line: "$line"');
      final match = _stackTraceRegex.firstMatch(line);
      print('Regex match result: ${match != null}');
      if (match != null) {
        print('Match groups: ${match.groups(List.generate(match.groupCount + 1, (i) => i))}');
        final packageName = match.group(1)!;
        final filePath = match.group(2)!;
        final lineNum = int.parse(match.group(3)!);
        final columnNum = int.parse(match.group(4)!);

        // RESOLVE THE REAL PATH
        // Convert package:test_project/main.dart to absolute file path
        final projectPath = _findFlutterProjectRoot();
        String absolutePath = "$projectPath\\lib\\$filePath";
        absolutePath = absolutePath.replaceAll('/', '\\'); // Windows backslashes

        print('STACK TRACE PARSED: $packageName/$filePath:$lineNum:$columnNum');
        print('ACTUAL FILE PATH: $absolutePath');

        // Find the error message (usually a few lines before the stack trace)
        String errorMessage = 'Unknown error';
        for (int i = lines.indexOf(line) - 1; i >= 0 && i > lines.indexOf(line) - 5; i--) {
          final errorLine = lines[i];
          if (_errorPatterns.any((pattern) => pattern.hasMatch(errorLine))) {
            errorMessage = errorLine.trim();
            break;
          }
        }

        final errorMessageObj = ErrorMessage(
          filePath: '$packageName/$filePath',
          line: lineNum,
          column: columnNum,
          errorMessage: errorMessage,
          contextLines: lines.length >= 10
              ? lines.sublist(lines.length - 10)
              : lines,
          timestamp: DateTime.now(),
        );

        print('🚨 Error detected: ${errorMessageObj.filePath}:${errorMessageObj.line}');

        // TRIGGER AI ANALYSIS - The critical glue code!
        _onStackTraceMatched(absolutePath, lineNum, errorMessage);

        _errorController.add(errorMessageObj);
        break; // Only process the first stack trace found
      }
    }
  }

  String _findFlutterExecutable() {
    // Try common flutter installation paths
    final possiblePaths = [
      r'C:\Users\HomePC\Desktop\ORAFLOW\flutter\bin\flutter.bat', // Relative to OraFlow
      r'C:\flutter\bin\flutter.bat', // Standard installation
      r'C:\src\flutter\bin\flutter.bat', // Alternative location
      'flutter', // In PATH (fallback)
    ];

    for (final path in possiblePaths) {
      if (File(path).existsSync()) {
        print('Found Flutter executable: $path');
        return path;
      }
    }

    // Fallback to just 'flutter' (assume it's in PATH)
    print('Flutter not found in common locations, trying PATH');
    return 'flutter';
  }

  String _findFlutterProjectRoot() {
    // CRITICAL: Only use explicitly set project root
    if (_projectRoot != null && Directory(_projectRoot!).existsSync()) {
      return _projectRoot!;
    }

    // DO NOT use auto-detection - user must explicitly select a project
    // This prevents accidental monitoring of the wrong project on hot restart
    throw Exception(
      'No project root set. Please select a project using the file picker before starting monitoring.'
    );
  }

  // CRITICAL GLUE METHOD: Connects terminal watcher to AI brain with RICH CONTEXT and VALIDATION
  void _onStackTraceMatched(String filePath, int line, String errorMessage) async {
    print('🧠 BRAIN TRIGGERED: Calling AI for $filePath at line $line with RICH CONTEXT');

    try {
      // ENHANCED: Use rich context for better AI understanding
      final fixResult = await _aiService.getFixWithRichContext(errorMessage, filePath, line);

      if (fixResult != null) {
        print('✅ ENHANCED AI RESPONSE RECEIVED: ${fixResult['explanation']}');
        print('🔧 Edits found: ${fixResult['edits']}');
        print('🧠 Rich Context Used: ${fixResult['rich_context_used']}');
        print('🎯 Error Type: ${fixResult['error_type']}');
        print('🏗️ Widget Type: ${fixResult['widget_type']}');
        print('⚡ State Management: ${fixResult['state_management']}');

        // ENHANCED: Extract rich context for validation
        final richContext = await _aiService.extractRichContext(filePath, line, errorMessage, false);
        
        // ENHANCED: Apply validation layer before sending to UI
        final validatedResult = await _aiService.applyFixWithValidation(fixResult, richContext);

        if (validatedResult != null) {
          print('🛡️ VALIDATION PASSED: Fix is safe to apply');
          // Send fix to UI via stream
          _aiFixController.add(validatedResult);
        } else {
          print('❌ VALIDATION FAILED: Fix was rejected for safety reasons');
          _aiFixController.add({
            'explanation': 'AI suggestion was rejected by validation layer for safety reasons.',
            'edits': [],
            'validation_blocked': true,
          });
        }
      } else {
        print('❌ AI returned null. Check your API Key or Network.');
      }
    } catch (e) {
      print('🚨 FATAL AI CALL ERROR: $e');
    }
  }

  // Check for build errors in real-time (called from stream listeners)
  void _checkForBuildErrors(String line) {
    // FIRST-ERROR-ONLY LOCK: If already fixing something, ignore ALL other errors
    if (_isLockedForFixing || _isCooldownActive) return;

    // Try Windows MSBuild format first: lib/main.dart(6,70): error G67247B7E: Expected ';'
    final windowsMatch = _windowsBuildErrorRegex.firstMatch(line);
    if (windowsMatch != null) {
      final filePath = windowsMatch.group(1)!;
      final lineNum = int.parse(windowsMatch.group(2)!);
      final column = int.parse(windowsMatch.group(3)!);
      final errorMsg = windowsMatch.group(4)!;

      final projectPath = _findFlutterProjectRoot();
      final absolutePath = filePath.startsWith('lib/')
          ? "$projectPath\\$filePath"
          : filePath.startsWith('/')
              ? filePath
              : "$projectPath\\$filePath";

      print('🎯 FOCUSING ON FIRST ERROR: $errorMsg at $filePath:$lineNum');
      print('🔒 Engine locked - ignoring subsequent errors until fix is applied');

      // LOCK THE ENGINE IMMEDIATELY
      _isLockedForFixing = true;

      _onCompilationErrorDetected(absolutePath, lineNum, 'Error: $errorMsg');
      return;
    }

    // Fallback to standard Dart format
    final dartMatch = _dartBuildErrorRegex.firstMatch(line);
    if (dartMatch != null) {
      final filePath = dartMatch.group(1)!;
      final lineNum = int.parse(dartMatch.group(2)!);
      final errorMsg = dartMatch.group(4)!;

      final projectPath = _findFlutterProjectRoot();
      final absolutePath = filePath.startsWith('lib/')
          ? "$projectPath\\$filePath"
          : filePath.startsWith('/')
              ? filePath
              : "$projectPath\\$filePath";

      print('🎯 FOCUSING ON FIRST ERROR: $errorMsg at $filePath:$lineNum');
      print('🔒 Engine locked - ignoring subsequent errors until fix is applied');

      // LOCK THE ENGINE IMMEDIATELY
      _isLockedForFixing = true;

      _onCompilationErrorDetected(absolutePath, lineNum, 'Error: $errorMsg');
      return;
    }
  }

  // Handle compilation errors (syntax/typos)
  void _onCompilationErrorDetected(String filePath, int line, String errorMessage) async {
    // DEDUPLICATION: Prevent duplicate notifications for same error
    final errorLocation = "$filePath:$line";
    if (_lastErrorLocation == errorLocation) {
      print('🔄 Duplicate error detected at $errorLocation, skipping...');
      return;
    }
    _lastErrorLocation = errorLocation;

    // Reset deduplication after 2 seconds
    _errorResetTimer?.cancel();
    _errorResetTimer = Timer(Duration(seconds: 2), () => _lastErrorLocation = null);

    print('🛠️ COMPILATION ERROR HANDLER: Calling AI for $filePath at line $line');

    try {
      final fixResult = await _aiService.getFix(errorMessage, filePath, line, isBuildError: true);

      if (fixResult != null) {
        print('✅ Compilation fix received: ${fixResult['explanation']}');

        // Send fix to UI via stream
        _aiFixController.add(fixResult);

        // Create ErrorMessage for compilation errors
        final errorMessageObj = ErrorMessage(
          filePath: filePath.split('\\').last, // Just filename for compilation errors
          line: line,
          column: 1, // Default for compilation errors
          errorMessage: errorMessage,
          contextLines: [], // No context for compilation errors
          timestamp: DateTime.now(),
        );

        _errorController.add(errorMessageObj);
      } else {
        print('❌ AI returned null for compilation error.');
      }
    } catch (e) {
      print('🚨 FATAL COMPILATION ERROR HANDLER: $e');
    }
  }

  // Analyze build failure when Flutter process exits with non-zero code
  void _analyzeBuildFailure() {
    print('🔍 Analyzing recent logs for build error details...');

    // Search recent logs for build errors
    for (final line in _recentLogs.reversed) { // Check most recent logs first
      // Try Windows MSBuild format first: lib/main.dart(6,70): error G67247B7E: Expected ';'
      var match = _windowsBuildErrorRegex.firstMatch(line);
      if (match != null) {
        final filePath = match.group(1)!;
        final lineNum = int.parse(match.group(2)!);
        final column = int.parse(match.group(3)!);
        final errorMsg = match.group(4)!;

        final projectPath = _findFlutterProjectRoot();
        final absolutePath = filePath.startsWith('lib/')
            ? "$projectPath\\$filePath"
            : filePath.startsWith('/')
                ? filePath
                : "$projectPath\\$filePath";

        print('🚨 WINDOWS BUILD ERROR FOUND: $errorMsg at $filePath:$lineNum');
        _onCompilationErrorDetected(absolutePath, lineNum, 'Error: $errorMsg');
        return; // Process only the first build error found
      }

      // Fallback to standard Dart format: lib/main.dart:6:70: Error: Expected ';'
      match = _dartBuildErrorRegex.firstMatch(line);
      if (match != null) {
        final filePath = match.group(1)!;
        final lineNum = int.parse(match.group(2)!);
        final errorMsg = match.group(4)!;

        final projectPath = _findFlutterProjectRoot();
        final absolutePath = filePath.startsWith('lib/')
            ? "$projectPath\\$filePath"
            : filePath.startsWith('/')
                ? filePath
                : "$projectPath\\$filePath";

        print('🚨 BUILD ERROR FOUND: $errorMsg at $filePath:$lineNum');
        _onCompilationErrorDetected(absolutePath, lineNum, 'Error: $errorMsg');
        return; // Process only the first build error found
      }

      // Check for URI errors
      final uriMatch = _uriErrorRegex.firstMatch(line);
      if (uriMatch != null) {
        final missingPackage = uriMatch.group(1)!;
        print('🚨 DEPENDENCY ERROR FOUND: Missing package $missingPackage');
        _onDependencyErrorDetected(missingPackage);
        return;
      }

      // Check for pubspec errors
      final pubspecMatch = _pubspecErrorRegex.firstMatch(line);
      if (pubspecMatch != null) {
        final lineNum = int.parse(pubspecMatch.group(1)!);
        print('🚨 PUBSPEC ERROR FOUND: Error at line $lineNum');
        _onPubspecErrorDetected(lineNum, line);
        return;
      }
    }

    print('❓ No specific build error pattern found in logs');
  }

  // Handle dependency/package errors
  void _onDependencyErrorDetected(String missingPackage) {
    print('📦 DEPENDENCY ERROR HANDLER: Missing package $missingPackage');

    // Create a generic error message for missing dependencies
    final errorMessageObj = ErrorMessage(
      filePath: 'pubspec.yaml',
      line: 1,
      column: 1,
      errorMessage: "Missing dependency: $missingPackage. Add it to pubspec.yaml",
      contextLines: [],
      timestamp: DateTime.now(),
    );

    _errorController.add(errorMessageObj);
  }

  // Handle pubspec.yaml errors
  void _onPubspecErrorDetected(int line, String errorLine) {
    print('📄 PUBSPEC ERROR HANDLER: Error at line $line');

    final errorMessageObj = ErrorMessage(
      filePath: 'pubspec.yaml',
      line: line,
      column: 1,
      errorMessage: errorLine,
      contextLines: [],
      timestamp: DateTime.now(),
    );

    _errorController.add(errorMessageObj);
  }

  // Handle UI overflow warnings with enhanced AI prompts
  void _onOverflowWarningDetected(String pixels, String side) {
    print('⚠️ UI OVERFLOW WARNING: $pixels pixels on $side');

    final errorMessageObj = ErrorMessage(
      filePath: 'UI Layout',
      line: 1,
      column: 1,
      errorMessage: "UI OVERFLOW: RenderFlex overflowed by $pixels pixels on the $side. This widget is too large for its container. SOLUTIONS: 1) Wrap in Expanded() for flexible sizing, 2) Use SingleChildScrollView for scrollable content, 3) Check parent Container constraints, 4) Use FittedBox for text scaling, 5) Implement responsive layouts with MediaQuery.",
      contextLines: [],
      timestamp: DateTime.now(),
    );

    _errorController.add(errorMessageObj);
  }

  // Handle missing asset errors with enhanced AI prompts
  void _onAssetErrorDetected(String assetPath) {
    print('📁 MISSING ASSET ERROR: $assetPath');

    final errorMessageObj = ErrorMessage(
      filePath: 'pubspec.yaml',
      line: 1,
      column: 1,
      errorMessage: "MISSING ASSET: Unable to load '$assetPath'. CAUSES: 1) File doesn't exist in the path, 2) Not listed in pubspec.yaml assets section, 3) Incorrect path or case sensitivity. SOLUTIONS: 1) Verify file exists at exact path, 2) Add to pubspec.yaml under 'assets:' section, 3) Use correct relative path from project root, 4) Ensure proper indentation in pubspec.yaml.",
      contextLines: [],
      timestamp: DateTime.now(),
    );

    _errorController.add(errorMessageObj);
  }

  // COOLDOWN MECHANISM: Prevents repeated error detection after fixes
  void applyCooldown() {
    _isCooldownActive = true;
    print('🛡️ Cooldown activated - ignoring errors for 5 seconds while app reloads');
    Timer(Duration(seconds: 5), () {
      _isCooldownActive = false;
      print("🛡️ Monitoring resumed after cooldown");
    });
  }

  // FIRST-ERROR-ONLY: Unlock the engine to listen for new errors
  void unlock() {
    _isLockedForFixing = false;
    _lastErrorLocation = null;
    print('🔓 Engine unlocked - ready for new errors');
  }

  // EMERGENCY RESET: Force unlock everything if AI gets stuck
  void emergencyReset() {
    _isLockedForFixing = false;
    _isCooldownActive = false;
    _lastErrorLocation = null;
    _errorResetTimer?.cancel();
    print('🚨 EMERGENCY RESET: All locks cleared');
  }

  // Handle Android errors from ADB Bridge
  void handleAndroidError(Map<String, dynamic> androidError) {
    print('📱 ANDROID ERROR RECEIVED: ${androidError['error_type']} - ${androidError['message']}');

    // Check if this is a permission error that needs special handling
    if (androidError['error_type'] == 'permission_denied') {
      _handleAndroidPermissionError(androidError);
      return;
    }

    // For other Android errors, treat them like compilation errors
    _handleAndroidRuntimeError(androidError);
  }

  void _handleAndroidPermissionError(Map<String, dynamic> androidError) {
    final permissionType = androidError['permission_type'] ?? 'unknown';
    final packageName = androidError['package_name'] ?? 'unknown';
    final deviceInfo = androidError['device_id'] ?? 'unknown device';

    print('🔒 PERMISSION ERROR DETECTED: $permissionType permission denied on $deviceInfo');

    // Create a special error message for permission issues
    final errorMessageObj = ErrorMessage(
      filePath: 'AndroidManifest.xml',
      line: 1,
      column: 1,
      errorMessage: "ANDROID PERMISSION ERROR: $permissionType permission denied on $deviceInfo. SOLUTIONS: 1) Add $permissionType permission to AndroidManifest.xml, 2) Request runtime permission in your Flutter code, 3) Check app settings on device to ensure permission is granted.",
      contextLines: [],
      timestamp: DateTime.now(),
    );

    _errorController.add(errorMessageObj);

    // Send to AI for analysis
    _aiFixController.add({
      'explanation': 'Android permission error detected. The app is trying to access $permissionType but the permission is not granted.',
      'edits': [
        {
          'file': 'android/app/src/main/AndroidManifest.xml',
          'line': 1,
          'old_line_content': '',
          'new_line_content': '<uses-permission android:name="android.permission.${_getAndroidPermissionName(permissionType)}" />',
        }
      ]
    });
  }

  void _handleAndroidRuntimeError(Map<String, dynamic> androidError) {
    final errorType = androidError['error_type'];
    final message = androidError['message'];
    final deviceInfo = androidError['device_id'] ?? 'unknown device';

    print('🚨 ANDROID RUNTIME ERROR: $errorType on $deviceInfo');

    // Create error message for Android runtime errors
    final errorMessageObj = ErrorMessage(
      filePath: 'Android Runtime',
      line: 1,
      column: 1,
      errorMessage: "ANDROID RUNTIME ERROR: $errorType detected on $deviceInfo. Message: $message. This is a native Android error that may require platform-specific fixes.",
      contextLines: [],
      timestamp: DateTime.now(),
    );

    _errorController.add(errorMessageObj);

    // Send to AI for analysis
    _aiFixController.add({
      'explanation': 'Android runtime error detected. This requires platform-specific analysis.',
      'edits': []
    });
  }

  String _getAndroidPermissionName(String permissionType) {
    switch (permissionType) {
      case 'camera':
        return 'CAMERA';
      case 'location':
        return 'ACCESS_FINE_LOCATION';
      case 'storage':
        return 'READ_EXTERNAL_STORAGE';
      case 'network':
        return 'INTERNET';
      case 'phone_state':
        return 'READ_PHONE_STATE';
      case 'contacts':
        return 'READ_CONTACTS';
      case 'sms':
        return 'SEND_SMS';
      default:
        return permissionType.toUpperCase();
    }
  }

  // Set the project root to monitor
  void setProjectRoot(String path) {
    _projectRoot = path;
    print('📁 Project root set to: $path');
  }

  // Send input to the Flutter process (for hot reload 'r' or clear 'c')
  void sendInput(String input) {
    if (_flutterProcess != null && _isMonitoring) {
      _flutterProcess!.stdin.writeln(input);
      print('📤 Sent input to Flutter process: $input');
    }
  }

  void dispose() {
    stopMonitoring();
    _errorController.close();
    _logController.close();
    _aiFixController.close();
  }
}
