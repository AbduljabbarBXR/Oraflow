import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../services/semantic_analyzer_service.dart';
import '../services/resource_guard_service.dart';
import '../widgets/fix_preview_panel.dart';
import 'validation_service.dart';
import 'config_service.dart';

// ENHANCED: Rich Error Context for Intelligent Auto-Fix
class RichErrorContext {
  final String filePath;
  final int line;
  final String errorMessage;
  final String errorType; // 'compilation', 'runtime', 'semantic'
  final String widgetType; // 'StatefulWidget', 'StatelessWidget', 'Provider'
  final String stateManagement; // 'Provider', 'Bloc', 'Riverpod', 'Getx'
  final List<String> imports;
  final String parentWidget;
  final String projectArchitecture;
  final String recentChanges; // Git diff context
  final String fullFileContent;
  final String codeSnippet;
  final String projectStructure;

  RichErrorContext({
    required this.filePath,
    required this.line,
    required this.errorMessage,
    required this.errorType,
    required this.widgetType,
    required this.stateManagement,
    required this.imports,
    required this.parentWidget,
    required this.projectArchitecture,
    required this.recentChanges,
    required this.fullFileContent,
    required this.codeSnippet,
    required this.projectStructure,
  });

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'line': line,
        'errorMessage': errorMessage,
        'errorType': errorType,
        'widgetType': widgetType,
        'stateManagement': stateManagement,
        'imports': imports,
        'parentWidget': parentWidget,
        'projectArchitecture': projectArchitecture,
        'recentChanges': recentChanges,
        'fullFileContent': fullFileContent,
        'codeSnippet': codeSnippet,
        'projectStructure': projectStructure,
      };
}

class FixAction {
  final String explanation;
  final List<Edit> edits;

  FixAction({
    required this.explanation,
    required this.edits,
   });

  factory FixAction.fromJson(Map<String, dynamic> json) {
    return FixAction(
      explanation: json['explanation'] as String,
      edits: (json['edits'] as List<dynamic>)
          .map((edit) => Edit.fromJson(edit as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'explanation': explanation,
        'edits': edits.map((edit) => edit.toJson()).toList(),
      };
}

class Edit {
  final String file;
  final int line;
  final String oldLineContent;
  final String newLineContent;

  Edit({
    required this.file,
    required this.line,
    required this.oldLineContent,
    required this.newLineContent,
  });

  factory Edit.fromJson(Map<String, dynamic> json) {
    return Edit(
      file: json['file'] as String,
      line: json['line'] as int,
      oldLineContent: json['old_line_content'] as String,
      newLineContent: json['new_line_content'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'file': file,
        'line': line,
        'old_line_content': oldLineContent,
        'new_line_content': newLineContent,
      };
}

class AiService {
  final ResourceGuardService _resourceGuard = ResourceGuardService();
  // Simple rate limiting (sliding window)
  final List<DateTime> _requestTimestamps = [];
  static const int MAX_REQUESTS_PER_MINUTE = 20;

  // Circuit breaker on repeated failures
  int _failureCount = 0;
  DateTime? _failureWindowStart;
  static const int FAILURE_THRESHOLD = 5;
  static const Duration FAILURE_WINDOW = Duration(minutes: 5);
  static const Duration CIRCUIT_COOLDOWN = Duration(minutes: 2);
  DateTime? _circuitOpenedAt;

  // Singleton instance for global access and async init
  static final AiService instance = AiService._internal();

  factory AiService() => instance;

  AiService._internal();

  // Cached API key loaded asynchronously at startup or when updated
  String _apiKeyCached = '';

  Future<void> ensureApiKeyLoaded() async {
    try {
      final key = await ConfigService.getApiKey();
      if (key != null && key.isNotEmpty) _apiKeyCached = key;
    } catch (e) {
      // ignore
    }
  }

  Future<Map<String, dynamic>?> getFix(String errorLog, String filePath, int line, {bool isBuildError = false}) async {
    try {
      // RESOURCE GUARD: Check if we can make AI request
      if (!_resourceGuard.canMakeAiRequest()) {
        print('🛡️ AI Service: Resource guard blocked AI request due to high resource usage');
        return {
          "explanation": "Cannot process AI request due to high system resource usage. Please close other applications or wait for resources to free up.",
          "edits": [],
          "resource_blocked": true,
        };
      }

      // Circuit breaker: if open and not cooled down, block
      if (_circuitOpenedAt != null) {
        final cooled = DateTime.now().difference(_circuitOpenedAt!) > CIRCUIT_COOLDOWN;
        if (!cooled) {
          print('🛑 AI Service: Circuit breaker open - temporarily blocking requests');
          return {
            "explanation": "AI temporarily unavailable due to repeated failures. Try again later.",
            "edits": [],
            "circuit_open": true,
          };
        } else {
          // Close circuit
          _circuitOpenedAt = null;
          _failureCount = 0;
          _failureWindowStart = null;
        }
      }

      // Rate limiting: sliding window of requests per minute
      final now = DateTime.now();
      _requestTimestamps.removeWhere((t) => now.difference(t) > Duration(minutes: 1));
      if (_requestTimestamps.length >= MAX_REQUESTS_PER_MINUTE) {
        print('⏱️ AI Service: Rate limit exceeded for requests per minute');
        return {
          "explanation": "Rate limit exceeded. Please wait a moment and try again.",
          "edits": [],
          "rate_limited": true,
        };
      }
      _requestTimestamps.add(now);

      // Increment AI request counter
      _resourceGuard.incrementAiRequests();

      print('🤖 AI Service: Processing $filePath at line $line (buildError: $isBuildError)');
      print('🤖 AI Service: Error log: $errorLog');

      final file = File(filePath);
      final fileExists = await file.exists();
      print('🤖 AI Service: File exists at $filePath: $fileExists');

      if (!fileExists) {
        print('❌ AI Service: File does not exist, cannot read context');
        // For build errors, try programmatic fix even without file
        if (isBuildError && errorLog.contains('Expected')) {
          print('🔧 Attempting programmatic fix for compilation error (no file context)');
          _resourceGuard.decrementAiRequests();
          return _generateProgrammaticFixNoFile(errorLog, filePath, line);
        }
        _resourceGuard.decrementAiRequests();
        return null;
      }

      final lines = await file.readAsLines();
      print('🤖 AI Service: Successfully read ${lines.length} lines from file');

      // IMPROVED SYNTAX CHECK: Prevent semicolon hang on control flow
      String targetLine = lines[line - 1].trim();

      // If it's a build error and NOT an 'if/else/for' block, try programmatic fix
      if (isBuildError && errorLog.contains('Expected') && !_isControlFlow(targetLine)) {
        print('🔧 Attempting programmatic fix for compilation error');
        final programmaticFix = _generateProgrammaticFix(errorLog, filePath, line, lines);
        if (programmaticFix != null) {
          print('✅ Programmatic fix generated, skipping AI call');
          _resourceGuard.decrementAiRequests();
          return programmaticFix;
        }
      }

      // ALWAYS FALLBACK TO GROQ CLOUD (The True Brain)
      print("📡 Consulting Groq Cloud (Llama 3.3 70B)...");
      final result = await _callGroqAPI(errorLog, filePath, line, lines);
      _resourceGuard.decrementAiRequests();
      return result;
    } catch (e) {
      print("Fix Parse Error: $e");
      _resourceGuard.decrementAiRequests();
      // Track failure
      _recordFailure();
    }
    return null;
  }

  void _recordFailure() {
    final now = DateTime.now();
    if (_failureWindowStart == null || now.difference(_failureWindowStart!) > FAILURE_WINDOW) {
      _failureWindowStart = now;
      _failureCount = 1;
    } else {
      _failureCount++;
    }

    if (_failureCount >= FAILURE_THRESHOLD) {
      _circuitOpenedAt = DateTime.now();
      print('🚨 AI Service: Circuit opened due to repeated failures');
    }
  }

  Future<Map<String, dynamic>?> _callGroqAPI(String errorLog, String filePath, int line, List<String> lines) async {
    // PHASE 3: Deep Context - Grab 15 lines before and after for better AI understanding
    int start = (line - 15).clamp(0, lines.length);
    int end = (line + 15).clamp(0, lines.length);
    String codeSnippet = lines.sublist(start, end).join('\n');

    // Create SURGICAL AI prompt - focus only on the specific error
    final String systemPrompt = "You are a surgical code repair agent. You MUST respond in STRICT JSON format only. No conversational text. No markdown.\n\n"
                               "CRITICAL INSTRUCTIONS:\n"
                               "- Fix ONLY the syntax error at the specified line\n"
                               "- Do NOT refactor the entire file\n"
                               "- Do NOT add extra widgets unless absolutely necessary for build to pass\n"
                               "- Make the MINIMAL change required to fix the compilation error\n"
                               "- Return ONLY valid JSON with this exact schema:\n"
                               "{\"explanation\": \"Brief explanation of the fix\", \"edits\": [{\"file\": \"string\", \"line\": number, \"old_line_content\": \"string\", \"new_line_content\": \"string\"}]}";

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "llama-3.3-70b-versatile",
        "messages": [
          {
            "role": "system",
            "content": systemPrompt
          },
          {
            "role": "user",
            "content": "FIX THIS ERROR:\nLog: $errorLog\nFile: $filePath\nLine: $line\nCode:\n$codeSnippet"
          }
        ],
        "temperature": 0.1, // PHASE 1: Lower temperature for stable JSON
        "response_format": { "type": "json_object" } // PHASE 1: FORCE GROQ JSON MODE
      }),
    );

    if (response.statusCode == 200) {
      String content = jsonDecode(response.body)['choices'][0]['message']['content'];

      // PHASE 1 & 4: IRONCLAD JSON PARSER with Brace-Seeker
      try {
        // Find the first '{' and last '}' to extract JSON even if AI adds text
        final startBrace = content.indexOf('{');
        final endBrace = content.lastIndexOf('}');
        if (startBrace != -1 && endBrace != -1) {
          content = content.substring(startBrace, endBrace + 1);
        }

        final Map<String, dynamic> data = jsonDecode(content);

        // SAFE ACCESS with validation
        return {
          "explanation": data['explanation']?.toString() ?? "No explanation provided.",
          "edits": data['edits'] ?? []
        };
      } catch (e) {
        print("❌ JSON Cleaning failed: $e");
        throw Exception("AI sent invalid data format - expected JSON");
      }
    }
    return null;
  }

  bool _isControlFlow(String line) {
    final keywords = ['if', 'else', 'for', 'while', 'switch', 'class', 'void', 'try', 'catch'];
    return keywords.any((k) => line.startsWith(k)) || line.endsWith('{') || line.endsWith('}');
  }

  Future<String?> _extractCodeSnippet(String filePath, int lineNumber) async {
    try {
      // Handle both absolute paths and relative paths from test project
      String fullPath;
      if (filePath.startsWith('test_project/')) {
        // Convert relative test project path to absolute
        fullPath = r'C:\Users\HomePC\Desktop\test_project\lib\main.dart';
      } else if (filePath.startsWith('/')) {
        // Already absolute
        fullPath = filePath;
      } else {
        // Relative to current directory
        fullPath = filePath;
      }

      final file = File(fullPath);
      if (!await file.exists()) {
        print('File does not exist: $fullPath');
        return null;
      }

      final lines = await file.readAsLines();
      final startLine = (lineNumber - 10).clamp(0, lines.length);
      final endLine = (lineNumber + 10).clamp(0, lines.length);

      final snippetLines = lines.sublist(startLine, endLine);
      final numberedLines = <String>[];

      for (int i = 0; i < snippetLines.length; i++) {
        final actualLineNumber = startLine + i + 1;
        final marker = actualLineNumber == lineNumber ? ' >>> ' : '     ';
        numberedLines.add('${actualLineNumber.toString().padLeft(4)}$marker${snippetLines[i]}');
      }

      return numberedLines.join('\n');
    } catch (e) {
      print('Error reading file $filePath: $e');
      return null;
    }
  }

  String _createPrompt(String errorLog, String codeSnippet, int lineNumber) {
    return '''
I found this Flutter error:

ERROR LOG:
$errorLog

CODE SNIPPET (around line $lineNumber):
$codeSnippet

Please analyze this error and provide a fix. Focus on the most likely cause and provide a simple, correct solution.
''';
  }

  // Generate programmatic fix for common compilation errors
  Map<String, dynamic>? _generateProgrammaticFix(String errorLog, String filePath, int line, List<String> lines) {
    try {
      if (line <= 0 || line > lines.length) return null;

      final lineIndex = line - 1; // Convert to 0-based indexing
      final currentLine = lines[lineIndex];

      // Handle missing semicolon errors
      if (errorLog.contains('Expected') && errorLog.contains(';')) {
        // Check if line ends with semicolon
        final trimmedLine = currentLine.trimRight();
        if (!trimmedLine.endsWith(';')) {
          // Add semicolon to the line
          final fixedLine = trimmedLine + ';';

          return {
            "explanation": "Added missing semicolon to fix compilation error",
            "edits": [
              {
                "file": filePath,
                "line": line,
                "old_line_content": currentLine,
                "new_line_content": fixedLine
              }
            ]
          };
        }
      }

      // Handle other common syntax errors here as needed
      // Add more patterns for brackets, parentheses, etc.

    } catch (e) {
      print('❌ Programmatic fix generation failed: $e');
    }

    return null;
  }

  // Generate programmatic fix when file cannot be read
  Map<String, dynamic>? _generateProgrammaticFixNoFile(String errorLog, String filePath, int line) {
    // For missing semicolon errors, we can generate a basic fix without file content
    if (errorLog.contains('Expected') && errorLog.contains(';')) {
      return {
        "explanation": "Added missing semicolon to fix compilation error (inferred from error message)",
        "edits": [
          {
            "file": filePath,
            "line": line,
            "old_line_content": "", // Empty since we don't have file content
            "new_line_content": ";" // Just add semicolon
          }
        ]
      };
    }

    return null;
  }

  // Method to update API key
  void updateApiKey(String newKey) {
    // Persist the API key via ConfigService and update cache
    ConfigService.setApiKey(newKey);
    _apiKeyCached = newKey;
    print('API key updated and saved to secure storage');
  }

  String get apiKey => _apiKeyCached;

  // ENHANCED: Get Fix with Rich Context
  Future<Map<String, dynamic>?> getFixWithRichContext(String errorLog, String filePath, int line, {bool isBuildError = false}) async {
    try {
      // RESOURCE GUARD: Check if we can make AI request
      if (!_resourceGuard.canMakeAiRequest()) {
        print('🛡️ AI Service: Resource guard blocked AI request due to high resource usage');
        return {
          "explanation": "Cannot process AI request due to high system resource usage. Please close other applications or wait for resources to free up.",
          "edits": [],
          "resource_blocked": true,
        };
      }

      // Increment AI request counter
      _resourceGuard.incrementAiRequests();

      print('🤖 AI Service: Processing $filePath at line $line with RICH CONTEXT (buildError: $isBuildError)');
      print('🤖 AI Service: Error log: $errorLog');

      final file = File(filePath);
      final fileExists = await file.exists();
      print('🤖 AI Service: File exists at $filePath: $fileExists');

      if (!fileExists) {
        print('❌ AI Service: File does not exist, cannot read context');
        // For build errors, try programmatic fix even without file
        if (isBuildError && errorLog.contains('Expected')) {
          print('🔧 Attempting programmatic fix for compilation error (no file context)');
          _resourceGuard.decrementAiRequests();
          return _generateProgrammaticFixNoFile(errorLog, filePath, line);
        }
        _resourceGuard.decrementAiRequests();
        return null;
      }

      // ENHANCED: Extract rich context
      final richContext = await extractRichContext(filePath, line, errorLog, isBuildError);
      print('🧠 RICH CONTEXT EXTRACTED: ${richContext.toJson()}');

      // ALWAYS FALLBACK TO GROQ CLOUD (The True Brain) with enhanced prompt
      print("📡 Consulting Groq Cloud (Llama 3.3 70B) with RICH CONTEXT...");
      final result = await _callGroqAPIWithRichContext(richContext);
      _resourceGuard.decrementAiRequests();
      return result;
    } catch (e) {
      print("Fix Parse Error: $e");
      _resourceGuard.decrementAiRequests();
    }
    return null;
  }

  // ENHANCED: Extract Rich Context for Intelligent Analysis
  Future<RichErrorContext> extractRichContext(String filePath, int line, String errorMessage, bool isBuildError) async {
    final file = File(filePath);
    final fullFileContent = await file.readAsString();
    final lines = fullFileContent.split('\n');

    // ENHANCED: Context Analysis
    final errorType = _classifyError(errorMessage, isBuildError);
    final widgetType = _detectWidgetType(lines, line);
    final stateManagement = _detectStateManagement(fullFileContent);
    final imports = _extractImports(fullFileContent);
    final parentWidget = _findParentWidget(lines, line);
    final projectArchitecture = _analyzeProjectStructure(filePath);
    final recentChanges = await _getGitDiff(filePath);
    final projectStructure = await _getProjectStructure(filePath);

    // ENHANCED: Smart code snippet (50 lines total)
    final codeSnippet = _generateSmartCodeSnippet(lines, line);

    return RichErrorContext(
      filePath: filePath,
      line: line,
      errorMessage: errorMessage,
      errorType: errorType,
      widgetType: widgetType,
      stateManagement: stateManagement,
      imports: imports,
      parentWidget: parentWidget,
      projectArchitecture: projectArchitecture,
      recentChanges: recentChanges,
      fullFileContent: fullFileContent,
      codeSnippet: codeSnippet,
      projectStructure: projectStructure,
    );
  }

  // ENHANCED: Error Classification System
  String _classifyError(String errorMessage, bool isBuildError) {
    if (isBuildError) return 'compilation';
    
    final runtimePatterns = [
      'Null check operator used on a null value',
      'Unhandled Exception',
      'Type Error',
      'Range Error',
      'Argument Error',
    ];
    
    final semanticPatterns = [
      'Logic Error',
      'State Management',
      'Widget Lifecycle',
      'Performance Issue',
    ];

    if (runtimePatterns.any((pattern) => errorMessage.toLowerCase().contains(pattern.toLowerCase()))) {
      return 'runtime';
    }
    
    if (semanticPatterns.any((pattern) => errorMessage.toLowerCase().contains(pattern.toLowerCase()))) {
      return 'semantic';
    }

    return 'unknown';
  }

  // ENHANCED: Widget Type Detection
  String _detectWidgetType(List<String> lines, int line) {
    // Look backwards from error line to find widget class
    for (int i = line - 1; i >= 0 && i > line - 20; i--) {
      final lineContent = lines[i].trim();
      
      if (lineContent.contains('class ') && lineContent.contains('extends StatelessWidget')) {
        return 'StatelessWidget';
      }
      if (lineContent.contains('class ') && lineContent.contains('extends StatefulWidget')) {
        return 'StatefulWidget';
      }
      if (lineContent.contains('class ') && lineContent.contains('extends InheritedWidget')) {
        return 'InheritedWidget';
      }
      if (lineContent.contains('class ') && lineContent.contains('Provider')) {
        return 'Provider';
      }
      if (lineContent.contains('class ') && lineContent.contains('Bloc')) {
        return 'Bloc';
      }
    }

    // Look at the error line itself
    final errorLine = lines[line - 1].trim();
    if (errorLine.contains('setState') || errorLine.contains('build')) {
      return 'StatefulWidget';
    }
    if (errorLine.contains('context.watch') || errorLine.contains('context.read')) {
      return 'Provider';
    }

    return 'Unknown';
  }

  // ENHANCED: State Management Detection
  String _detectStateManagement(String fileContent) {
    if (fileContent.contains('Provider.of') || fileContent.contains('context.watch') || fileContent.contains('context.read')) {
      return 'Provider';
    }
    if (fileContent.contains('BlocBuilder') || fileContent.contains('BlocProvider')) {
      return 'Bloc';
    }
    if (fileContent.contains('Consumer') || fileContent.contains('Riverpod')) {
      return 'Riverpod';
    }
    if (fileContent.contains('Get.') || fileContent.contains('GetBuilder')) {
      return 'Getx';
    }
    if (fileContent.contains('setState') && !fileContent.contains('StatefulWidget')) {
      return 'StatefulWidget';
    }
    return 'Unknown';
  }

  // ENHANCED: Import Analysis
  List<String> _extractImports(String fileContent) {
    final importLines = fileContent.split('\n')
        .where((line) => line.trim().startsWith('import'))
        .map((line) => line.trim().replaceAll('import ', '').replaceAll(';', ''))
        .toList();
    
    return importLines;
  }

  // ENHANCED: Parent Widget Detection
  String _findParentWidget(List<String> lines, int line) {
    // Look backwards to find the parent widget structure
    int braceCount = 0;
    String currentWidget = 'Unknown';
    
    for (int i = line - 1; i >= 0; i--) {
      final lineContent = lines[i].trim();
      
      // Count braces to understand nesting
      braceCount += (lineContent.split('').where((char) => char == '}').length);
      braceCount -= (lineContent.split('').where((char) => char == '{').length);
      
      // Find widget declarations
      if (lineContent.contains('Widget') && lineContent.contains('(')) {
        final widgetMatch = RegExp(r'(\w+)\s*\(').firstMatch(lineContent);
        if (widgetMatch != null) {
          currentWidget = widgetMatch.group(1) ?? 'Unknown';
          if (braceCount <= 0) break; // Found the parent
        }
      }
    }
    
    return currentWidget;
  }

  // ENHANCED: Project Architecture Analysis
  String _analyzeProjectStructure(String filePath) {
    final projectRoot = filePath.split('lib/').first;
    final libPath = '$projectRoot/lib';
    
    if (Directory('$libPath/models').existsSync()) {
      if (Directory('$libPath/services').existsSync()) {
        return 'MVVM';
      }
      if (Directory('$libPath/repositories').existsSync()) {
        return 'Clean Architecture';
      }
    }
    
    if (Directory('$libPath/blocs').existsSync() || Directory('$libPath/cubits').existsSync()) {
      return 'Bloc Pattern';
    }
    
    if (Directory('$libPath/providers').existsSync()) {
      return 'Provider Pattern';
    }
    
    if (Directory('$libPath/controllers').existsSync()) {
      return 'Getx Pattern';
    }
    
    return 'Unknown';
  }

  // ENHANCED: Git Integration for Recent Changes
  Future<String> _getGitDiff(String filePath) async {
    try {
      final result = await Process.run('git', ['diff', 'HEAD', '--', filePath]);
      return result.stdout.toString().trim();
    } catch (e) {
      return 'Git diff not available';
    }
  }

  // ENHANCED: Project Structure Analysis
  Future<String> _getProjectStructure(String filePath) async {
    try {
      final projectRoot = filePath.split('lib/').first;
      final result = await Process.run('find', ['$projectRoot/lib', '-type', 'f', '-name', '*.dart', '|', 'head', '-20']);
      return result.stdout.toString().trim();
    } catch (e) {
      return 'Project structure not available';
    }
  }

  // ENHANCED: Smart Code Snippet Generation
  String _generateSmartCodeSnippet(List<String> lines, int line) {
    // Get 25 lines before and after for comprehensive context
    int start = (line - 25).clamp(0, lines.length);
    int end = (line + 25).clamp(0, lines.length);
    
    final snippetLines = lines.sublist(start, end);
    final numberedLines = <String>[];
    
    for (int i = 0; i < snippetLines.length; i++) {
      final actualLineNumber = start + i + 1;
      final marker = actualLineNumber == line ? ' >>> ' : '     ';
      numberedLines.add('${actualLineNumber.toString().padLeft(4)}$marker${snippetLines[i]}');
    }
    
    return numberedLines.join('\n');
  }

  // ENHANCED: Groq API Call with Rich Context
  Future<Map<String, dynamic>?> _callGroqAPIWithRichContext(RichErrorContext context) async {
    // ENHANCED: Surgical AI prompt with full context
    final String enhancedPrompt = """
CRITICAL ERROR ANALYSIS:

ERROR: ${context.errorMessage}
TYPE: ${context.errorType}
LOCATION: ${context.filePath}:${context.line}
WIDGET: ${context.widgetType}
STATE: ${context.stateManagement}
ARCHITECTURE: ${context.projectArchitecture}

IMPORTS: ${context.imports.join(', ')}

PARENT WIDGET: ${context.parentWidget}

PROJECT CONTEXT:
${context.projectStructure}

CODE SNIPPET (50 lines total):
${context.codeSnippet}

GITHUB DIFF (Recent Changes):
${context.recentChanges}

INSTRUCTIONS:
1. Analyze the error in FULL context
2. Consider project architecture and patterns
3. Check for state management conflicts
4. Verify widget lifecycle issues
5. Suggest MINIMAL, TARGETED fix
6. Return ONLY valid JSON with exact schema
""";

    final response = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "llama-3.3-70b-versatile",
        "messages": [
          {
            "role": "system",
            "content": "You are a surgical code repair agent with FULL PROJECT CONTEXT. You MUST respond in STRICT JSON format only. No conversational text. No markdown.\n\nCRITICAL INSTRUCTIONS:\n- Fix ONLY the syntax error at the specified line\n- Do NOT refactor the entire file\n- Do NOT add extra widgets unless absolutely necessary for build to pass\n- Make the MINIMAL change required to fix the compilation error\n- Consider project architecture, state management, and widget patterns\n- Return ONLY valid JSON with this exact schema:\n{\"explanation\": \"Brief explanation of the fix\", \"edits\": [{\"file\": \"string\", \"line\": number, \"old_line_content\": \"string\", \"new_line_content\": \"string\"}]}"
          },
          {
            "role": "user",
            "content": enhancedPrompt
          }
        ],
        "temperature": 0.1,
        "response_format": { "type": "json_object" }
      }),
    );

    if (response.statusCode == 200) {
      String content = jsonDecode(response.body)['choices'][0]['message']['content'];

      // PHASE 1 & 4: IRONCLAD JSON PARSER with Brace-Seeker
      try {
        // Find the first '{' and last '}' to extract JSON even if AI adds text
        final startBrace = content.indexOf('{');
        final endBrace = content.lastIndexOf('}');
        if (startBrace != -1 && endBrace != -1) {
          content = content.substring(startBrace, endBrace + 1);
        }

        final Map<String, dynamic> data = jsonDecode(content);

        // SAFE ACCESS with validation
        return {
          "explanation": data['explanation']?.toString() ?? "No explanation provided.",
          "edits": data['edits'] ?? [],
          "rich_context_used": true,
          "error_type": context.errorType,
          "widget_type": context.widgetType,
          "state_management": context.stateManagement,
        };
      } catch (e) {
        print("❌ JSON Cleaning failed: $e");
        throw Exception("AI sent invalid data format - expected JSON");
      }
    }
    return null;
  }

  // ENHANCED: Validation Layer for AI Suggestions
  bool _validateAISuggestion(Map<String, dynamic> fixResult, RichErrorContext context) {
    try {
      print('🛡️ VALIDATION LAYER: Analyzing AI suggestion for safety...');
      
      final edits = fixResult['edits'] as List<dynamic>;
      
      for (final edit in edits) {
        final editMap = edit as Map<String, dynamic>;
        final oldLine = editMap['old_line_content'] as String;
        final newLine = editMap['new_line_content'] as String;
        
        // ENHANCED: Safety checks
        if (_containsDangerousPatterns(newLine)) {
          print('❌ VALIDATION FAILED: Dangerous pattern detected in AI suggestion');
          return false;
        }
        
        if (_breaksWidgetStructure(newLine, oldLine, context.widgetType)) {
          print('❌ VALIDATION FAILED: Widget structure would be broken');
          return false;
        }
        
        if (_introducesStateManagementConflict(newLine, context.stateManagement)) {
          print('❌ VALIDATION FAILED: State management conflict detected');
          return false;
        }
        
        if (_changesTooMuchCode(newLine, oldLine)) {
          print('❌ VALIDATION FAILED: AI suggestion changes too much code');
          return false;
        }
      }
      
      print('✅ VALIDATION PASSED: AI suggestion is safe to apply');
      return true;
    } catch (e) {
      print('⚠️ VALIDATION ERROR: Could not validate AI suggestion: $e');
      return false; // Fail-safe: don't apply if we can't validate
    }
  }

  // ENHANCED: Check for dangerous patterns
  bool _containsDangerousPatterns(String line) {
    final dangerousPatterns = [
      r'eval\(',
      r'Function\(',
      r'window\.',
      r'document\.',
      r'exec\(',
      r'system\(',
      r'Process\.run',
      r'File\.delete',
      r'Directory\.delete',
      r'import.*dart:io.*delete',
    ];

    return dangerousPatterns.any((pattern) => RegExp(pattern, caseSensitive: false).hasMatch(line));
  }

  // ENHANCED: Check if edit breaks widget structure
  bool _breaksWidgetStructure(String newLine, String oldLine, String widgetType) {
    // Check for critical widget structure changes
    if (widgetType == 'StatefulWidget' && newLine.contains('setState') && !oldLine.contains('setState')) {
      // Adding setState where there wasn't one might be problematic
      if (!newLine.contains('()') && !newLine.contains('=>')) {
        return true;
      }
    }

    // Check for widget lifecycle violations
    if (newLine.contains('build') && !oldLine.contains('build')) {
      return true; // Don't allow adding build methods
    }

    return false;
  }

  // ENHANCED: Check for state management conflicts
  bool _introducesStateManagementConflict(String newLine, String stateManagement) {
    if (stateManagement == 'Provider') {
      if (newLine.contains('BlocBuilder') || newLine.contains('BlocProvider')) {
        return true; // Mixing Provider with Bloc
      }
    }

    if (stateManagement == 'Bloc') {
      if (newLine.contains('context.watch') || newLine.contains('context.read')) {
        return true; // Mixing Bloc with Provider
      }
    }

    return false;
  }

  // ENHANCED: Check if edit changes too much code
  bool _changesTooMuchCode(String newLine, String oldLine) {
    // Calculate edit distance or check for excessive changes
    final oldWords = oldLine.trim().split(RegExp(r'\s+'));
    final newWords = newLine.trim().split(RegExp(r'\s+'));
    
    // If more than 50% of words are changed, it's probably too much
    final commonWords = oldWords.toSet().intersection(newWords.toSet()).length;
    final totalWords = oldWords.length + newWords.length;
    
    if (totalWords > 0 && (commonWords / totalWords) < 0.5) {
      return true;
    }

    return false;
  }

  // ENHANCED: Apply fix with validation
  Future<Map<String, dynamic>?> applyFixWithValidation(Map<String, dynamic> fixResult, RichErrorContext context) async {
    // VALIDATION LAYER: Check if AI suggestion is safe (static checks + analyze)
    if (!_validateAISuggestion(fixResult, context)) {
      print('🛡️ VALIDATION BLOCKED: AI suggestion rejected for safety reasons');
      return {
        "explanation": "AI suggestion was rejected by validation layer for safety reasons. Please review the suggested changes manually.",
        "edits": [],
        "validation_blocked": true,
      };
    }

    // Run static analysis validation by applying edits to temporary copy
    try {
      final edits = fixResult['edits'] as List<dynamic>;
      final projectRoot = context.filePath.contains('lib/') ? context.filePath.split('lib/').first : Directory.current.path;
      final valid = await ValidationService.validateEdits(edits, projectRoot);
      if (!valid) {
        print('🛡️ VALIDATION BLOCKED: Static analysis failed after applying edits');
        return {
          "explanation": "AI suggestion failed static analysis when applied to a sandbox copy. Please review the suggested changes manually.",
          "edits": [],
          "validation_blocked": true,
        };
      }
    } catch (e) {
      print('⚠️ VALIDATION ERROR: Could not run static validation: $e');
      return {
        "explanation": "Validation runtime error: $e",
        "edits": [],
        "validation_error": true,
      };
    }

    // If validation passes, return the fix
    return fixResult;
  }

  // Handle semantic errors from Semantic Analyzer Service
  Future<Map<String, dynamic>?> handleSemanticError(SemanticError semanticError) async {
    try {
      print('🤖 AI Service: Processing semantic error: ${semanticError.type}');
      
      // Create a specialized prompt for semantic errors
      final String semanticPrompt = '''
SEMANTIC ERROR ANALYSIS:

Error Type: ${semanticError.type}
Description: ${semanticError.description}
Context: ${semanticError.context}
Timestamp: ${semanticError.timestamp}

This is a logical/semantic error that doesn't produce traditional error logs.
The code may compile and run but doesn't behave as expected.

Please analyze this semantic error and provide a fix that addresses the underlying
logical issue. Focus on the root cause rather than syntax problems.

Return the fix in the same JSON format as regular errors.
''';

      // Call Groq API with semantic error context
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "system",
              "content": "You are a semantic error analysis expert. You MUST respond in STRICT JSON format only. Focus on logical and behavioral issues rather than syntax errors."
            },
            {
              "role": "user",
              "content": semanticPrompt
            }
          ],
          "temperature": 0.1,
          "response_format": { "type": "json_object" }
        }),
      );

      if (response.statusCode == 200) {
        String content = jsonDecode(response.body)['choices'][0]['message']['content'];

        // Parse JSON response
        try {
          final startBrace = content.indexOf('{');
          final endBrace = content.lastIndexOf('}');
          if (startBrace != -1 && endBrace != -1) {
            content = content.substring(startBrace, endBrace + 1);
          }

          final Map<String, dynamic> data = jsonDecode(content);

          return {
            "explanation": data['explanation']?.toString() ?? "Semantic error analysis complete.",
            "edits": data['edits'] ?? [],
            "semantic_error_type": semanticError.type,
            "semantic_error_description": semanticError.description,
          };
        } catch (e) {
          print("❌ Semantic error JSON parsing failed: $e");
          return {
            "explanation": "Semantic error detected but AI analysis failed.",
            "edits": [],
            "semantic_error_type": semanticError.type,
            "semantic_error_description": semanticError.description,
          };
        }
      }
    } catch (e) {
      print('❌ Semantic error handling failed: $e');
    }

    return {
      "explanation": "Could not analyze semantic error.",
      "edits": [],
      "semantic_error_type": semanticError.type,
      "semantic_error_description": semanticError.description,
    };
  }

  // ENHANCED: Preview Fix Before Applying
  Future<Map<String, dynamic>?> previewFix(String errorLog, String filePath, int line, {bool isBuildError = false}) async {
    try {
      print('🔍 AI Service: Generating fix preview for $filePath at line $line');
      
      // Get the fix as usual
      final fixResult = await getFixWithRichContext(errorLog, filePath, line, isBuildError: isBuildError);
      
      if (fixResult == null) {
        return {
          "preview_available": false,
          "message": "Could not generate fix preview"
        };
      }

      // Extract the edits for preview
      final edits = fixResult['edits'] as List<dynamic>;
      
      if (edits.isEmpty) {
        return {
          "preview_available": false,
          "message": "No edits suggested by AI"
        };
      }

      // Generate preview data for the first edit (most common case)
      final edit = edits[0] as Map<String, dynamic>;
      final editFile = edit['file'] as String;
      final editLine = edit['line'] as int;
      final oldContent = edit['old_line_content'] as String;
      final newContent = edit['new_line_content'] as String;

      // Read the file to get context
      final file = File(editFile);
      if (!await file.exists()) {
        return {
          "preview_available": false,
          "message": "File not found for preview"
        };
      }

      final lines = await file.readAsLines();
      
      // Generate before and after code snippets
      final beforeCode = FixPreviewHelper.generateBeforeCode(lines.join('\n'), editLine, 5);
      final afterCode = FixPreviewHelper.generateAfterCode(lines.join('\n'), editLine, newContent);

      // Generate change description
      String changeDescription = _generateChangeDescription(oldContent, newContent);

      return {
        "type": "preview_fix",
        "preview_available": true,
        "file_name": editFile.split('/').last,
        "file": editFile,
        "line_number": editLine,
        "before_code": beforeCode,
        "after_code": afterCode,
        "change_description": changeDescription,
        "original_fix": fixResult, // Include original fix data
        "preview_type": "side_by_side_diff"
      };

    } catch (e) {
      print('❌ Preview generation failed: $e');
      return {
        "preview_available": false,
        "message": "Preview generation failed: $e"
      };
    }
  }

  // Generate human-readable change description
  String _generateChangeDescription(String oldContent, String newContent) {
    final oldTrimmed = oldContent.trim();
    final newTrimmed = newContent.trim();

    if (oldTrimmed.isEmpty && newTrimmed.isNotEmpty) {
      return "Added: $newTrimmed";
    } else if (oldTrimmed.isNotEmpty && newTrimmed.isEmpty) {
      return "Removed: $oldTrimmed";
    } else if (oldTrimmed != newTrimmed) {
      return "Changed: $oldTrimmed → $newTrimmed";
    } else {
      return "No change detected";
    }
  }
}

String _loadApiKey() {
  try {
    // 1) Environment variable
    final env = Platform.environment['ORAFLOW_API_KEY'];
    if (env != null && env.isNotEmpty) return env;

    // 2) Local config file in app folder
    final configFile = File('oraflow_config.json');
    if (configFile.existsSync()) {
      try {
        final content = configFile.readAsStringSync();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final key = data['apiKey'] as String?;
        if (key != null && key.isNotEmpty) return key;
      } catch (e) {
        // ignore parsing errors
      }
    }

    print('⚠️ ORAFLOW: No API key found in environment or oraflow_config.json. AI requests will likely fail.');
  } catch (e) {
    // ignore
  }
  return '';
}
