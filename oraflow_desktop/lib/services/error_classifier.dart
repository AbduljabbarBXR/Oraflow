import 'dart:io';

class ErrorClassification {
  final String type;
  final String severity;
  final String description;
  final ColorBadge colorBadge;
  final String userFriendlyMessage;

  ErrorClassification({
    required this.type,
    required this.severity,
    required this.description,
    required this.colorBadge,
    required this.userFriendlyMessage,
  });
}

enum ColorBadge {
  red, orange, yellow, green, gray
}

class ErrorClassifier {
  // ENHANCED: Comprehensive error pattern matching
  static ErrorClassification classifyError(String errorMessage, bool isBuildError) {
    // 1. Build/Compilation Errors (Highest Priority)
    if (isBuildError || _isCompilationError(errorMessage)) {
      return ErrorClassification(
        type: 'compilation',
        severity: 'critical',
        description: 'Code cannot compile',
        colorBadge: ColorBadge.red,
        userFriendlyMessage: 'This error prevents your app from building. The code has syntax issues that must be fixed before the app can run.',
      );
    }

    // 2. Runtime Errors (High Priority)
    if (_isRuntimeError(errorMessage)) {
      return ErrorClassification(
        type: 'runtime',
        severity: 'critical',
        description: 'App crashes during execution',
        colorBadge: ColorBadge.orange,
        userFriendlyMessage: 'This error causes your app to crash when this code runs. It will work during build but fail when users interact with it.',
      );
    }

    // 3. Lint/Style Warnings (Medium Priority)
    if (_isLintWarning(errorMessage)) {
      return ErrorClassification(
        type: 'lint',
        severity: 'medium',
        description: 'Code style or convention issue',
        colorBadge: ColorBadge.yellow,
        userFriendlyMessage: 'This is a code quality issue. Your app will work, but following best practices will make your code more maintainable.',
      );
    }

    // 4. Semantic/Logic Issues (Low Priority)
    if (_isSemanticError(errorMessage)) {
      return ErrorClassification(
        type: 'semantic',
        severity: 'low',
        description: 'Logic or semantic issue',
        colorBadge: ColorBadge.green,
        userFriendlyMessage: 'This is a logic issue. Your code runs but may not behave as expected. Consider reviewing the implementation.',
      );
    }

    // 5. Unknown/Error (Default)
    return ErrorClassification(
      type: 'unknown',
      severity: 'unknown',
      description: 'Unable to classify automatically',
      colorBadge: ColorBadge.gray,
      userFriendlyMessage: 'This error type is not recognized. Please review the error message and consider manual investigation.',
    );
  }

  // ENHANCED: Compilation Error Detection
  static bool _isCompilationError(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Missing semicolon patterns
    final missingSemicolonPatterns = [
      r'expected.*semicolon',
      r'missing.*semicolon',
      r'expected.*\;',
      r'expected.*\,',
      r'expected.*\)',
      r'expected.*\}',
    ];

    // Bracket/parentheses patterns
    final bracketPatterns = [
      r'expected.*\{',
      r'expected.*\}',
      r'expected.*\(',
      r'expected.*\)',
      r'unexpected.*\}',
      r'unexpected.*\)',
      r'missing.*closing',
      r'unmatched.*parentheses',
      r'unmatched.*braces',
    ];

    // Type-related patterns
    final typePatterns = [
      r'type.*not.*found',
      r'undefined.*class',
      r'undefined.*variable',
      r'cannot.*resolve',
      r'import.*not.*found',
      r'package.*not.*found',
    ];

    // Method/function patterns
    final methodPatterns = [
      r'method.*not.*found',
      r'function.*not.*defined',
      r'undefined.*method',
      r'undefined.*function',
      r'cannot.*invoke',
    ];

    // All compilation patterns
    final allPatterns = [
      ...missingSemicolonPatterns,
      ...bracketPatterns,
      ...typePatterns,
      ...methodPatterns,
    ];

    return allPatterns.any((pattern) => RegExp(pattern, caseSensitive: false).hasMatch(lowerMessage));
  }

  // ENHANCED: Runtime Error Detection
  static bool _isRuntimeError(String message) {
    final lowerMessage = message.toLowerCase();
    
    final runtimePatterns = [
      // Null safety errors
      r'null.*check.*operator',
      r'null.*check.*used.*on.*null',
      r'null.*value.*error',
      r'null.*reference',
      r'null.*pointer',
      
      // Type cast errors
      r'type.*cast',
      r'cast.*exception',
      r'invalid.*cast',
      r'cannot.*cast',
      
      // Range errors
      r'range.*error',
      r'index.*out.*of.*range',
      r'index.*out.*of.*bounds',
      r'list.*index.*out',
      
      // State errors
      r'state.*error',
      r'illegal.*state',
      r'invalid.*state',
      
      // Format errors
      r'format.*exception',
      r'invalid.*format',
      r'parse.*error',
      
      // Network errors
      r'network.*error',
      r'connection.*error',
      r'timeout',
      r'host.*unreachable',
      
      // File system errors
      r'file.*not.*found',
      r'permission.*denied',
      r'access.*denied',
      r'io.*exception',
      
      // Memory errors
      r'out.*of.*memory',
      r'memory.*error',
      r'heap.*overflow',
      
      // Assertion errors
      r'assertion.*failed',
      r'assert.*error',
      r'failed.*assertion',
    ];

    return runtimePatterns.any((pattern) => RegExp(pattern, caseSensitive: false).hasMatch(lowerMessage));
  }

  // ENHANCED: Lint Warning Detection
  static bool _isLintWarning(String message) {
    final lowerMessage = message.toLowerCase();
    
    final lintPatterns = [
      // Code style patterns
      r'unused.*variable',
      r'unused.*import',
      r'unused.*function',
      r'unused.*parameter',
      r'unused.*field',
      r'unused.*local.*variable',
      
      // Naming conventions
      r'non.*conforming',
      r'naming.*convention',
      r'constant.*naming',
      r'variable.*naming',
      r'method.*naming',
      
      // Code quality
      r'dead.*code',
      r'unreachable.*code',
      r'duplicate.*code',
      r'complex.*method',
      r'too.*many.*parameters',
      r'long.*method',
      
      // Best practices
      r'avoid.*print',
      r'avoid.*debug',
      r'prefer.*const',
      r'prefer.*final',
      r'avoid.*dynamic',
      r'avoid.*var',
      
      // Performance
      r'inefficient.*code',
      r'performance.*issue',
      r'memory.*leak',
      r'expensive.*operation',
      
      // Documentation
      r'missing.*documentation',
      r'missing.*comment',
      r'document.*this',
    ];

    return lintPatterns.any((pattern) => RegExp(pattern, caseSensitive: false).hasMatch(lowerMessage));
  }

  // ENHANCED: Semantic Error Detection
  static bool _isSemanticError(String message) {
    final lowerMessage = message.toLowerCase();
    
    final semanticPatterns = [
      // Logic errors
      r'logic.*error',
      r'incorrect.*logic',
      r'wrong.*condition',
      r'incorrect.*comparison',
      r'off.*by.*one',
      
      // Algorithm issues
      r'algorithm.*error',
      r'incorrect.*algorithm',
      r'wrong.*implementation',
      r'inefficient.*algorithm',
      
      // Business logic
      r'business.*logic',
      r'incorrect.*calculation',
      r'wrong.*formula',
      r'invalid.*operation',
      
      // Data flow
      r'data.*flow',
      r'incorrect.*data',
      r'wrong.*value',
      r'invalid.*input',
      
      // State management
      r'state.*management',
      r'incorrect.*state',
      r'invalid.*transition',
      r'state.*corruption',
      
      // Architecture
      r'architecture.*issue',
      r'incorrect.*design',
      r'violation.*principle',
      r'coupling.*issue',
    ];

    return semanticPatterns.any((pattern) => RegExp(pattern, caseSensitive: false).hasMatch(lowerMessage));
  }

  // ENHANCED: Get Color Badge for UI
  static ColorBadge getColorBadgeForError(String errorMessage, bool isBuildError) {
    return classifyError(errorMessage, isBuildError).colorBadge;
  }

  // ENHANCED: Get User-Friendly Message
  static String getUserFriendlyMessage(String errorMessage, bool isBuildError) {
    return classifyError(errorMessage, isBuildError).userFriendlyMessage;
  }

  // ENHANCED: Get Error Type
  static String getErrorType(String errorMessage, bool isBuildError) {
    return classifyError(errorMessage, isBuildError).type;
  }

  // ENHANCED: Get Severity Level
  static String getSeverity(String errorMessage, bool isBuildError) {
    return classifyError(errorMessage, isBuildError).severity;
  }

  // ENHANCED: Get Description
  static String getDescription(String errorMessage, bool isBuildError) {
    return classifyError(errorMessage, isBuildError).description;
  }
}
