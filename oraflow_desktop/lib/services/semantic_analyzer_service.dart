import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class SemanticError {
  final String type;
  final String description;
  final String suggestedFix;
  final DateTime timestamp;
  final String context;

  SemanticError({
    required this.type,
    required this.description,
    required this.suggestedFix,
    required this.timestamp,
    required this.context,
  });
}

class SemanticAnalyzerService {
  // SINGLETON PATTERN
  static final SemanticAnalyzerService _instance = SemanticAnalyzerService._internal();
  factory SemanticAnalyzerService() => _instance;
  SemanticAnalyzerService._internal();

  bool _isRecording = false;
  bool _isAnalyzing = false;
  final List<SemanticEvent> _eventLog = [];
  final StreamController<SemanticError> _errorController = StreamController<SemanticError>.broadcast();
  final StreamController<bool> _recordingController = StreamController<bool>.broadcast();

  Stream<SemanticError> get semanticErrorStream => _errorController.stream;
  Stream<bool> get recordingStatusStream => _recordingController.stream;

  bool get isRecording => _isRecording;
  bool get isAnalyzing => _isAnalyzing;
  List<SemanticEvent> get eventLog => List.unmodifiable(_eventLog);

  // Recording state management
  void startRecording() {
    if (_isRecording) return;

    _isRecording = true;
    _eventLog.clear();
    _recordingController.add(true);
    print('🔍 Semantic Analysis: Recording session started');

    // Auto-stop recording after 5 minutes to prevent memory issues
    Future.delayed(const Duration(minutes: 5), () {
      if (_isRecording) {
        stopRecording();
        print('🔍 Semantic Analysis: Auto-stopped recording after 5 minutes');
      }
    });
  }

  void stopRecording() {
    if (!_isRecording) return;

    _isRecording = false;
    _recordingController.add(false);
    print('🔍 Semantic Analysis: Recording stopped, analyzing ${_eventLog.length} events');

    // Trigger analysis if we have enough events
    if (_eventLog.length > 5) {
      analyzeSession();
    }
  }

  void addEvent(SemanticEvent event) {
    if (!_isRecording) return;

    _eventLog.add(event);

    // Limit event log size to prevent memory issues
    if (_eventLog.length > 1000) {
      _eventLog.removeRange(0, 500);
    }

    // Auto-analyze if we have enough events and haven't analyzed recently
    if (_eventLog.length >= 20 && !_isAnalyzing) {
      Future.delayed(const Duration(seconds: 2), () {
        if (_isRecording && !_isAnalyzing) {
          analyzeSession();
        }
      });
    }
  }

  Future<void> analyzeSession() async {
    if (_isAnalyzing || _eventLog.isEmpty) return;

    _isAnalyzing = true;
    print('🔍 Semantic Analysis: Starting analysis of ${_eventLog.length} events');

    try {
      // Analyze different types of semantic errors
      await _analyzeButtonClickIssues();
      await _analyzeStateManagementIssues();
      await _analyzeWidgetTreeIssues();
      await _analyzeLogicFlowIssues();

      print('🔍 Semantic Analysis: Analysis completed');
    } catch (e) {
      print('🔍 Semantic Analysis: Error during analysis: $e');
    } finally {
      _isAnalyzing = false;
    }
  }

  Future<void> _analyzeButtonClickIssues() async {
    // Look for button clicks that don't trigger expected actions
    final buttonClicks = _eventLog.where((event) => event.type == 'button_click').toList();
    final stateChanges = _eventLog.where((event) => event.type == 'state_change').toList();

    for (final click in buttonClicks) {
      // Check if there's a state change within 1 second
      final hasStateChange = stateChanges.any((change) =>
          change.timestamp.difference(click.timestamp).inMilliseconds.abs() < 1000 &&
          change.timestamp.isAfter(click.timestamp));

      if (!hasStateChange) {
        // Check if there are any widget rebuilds
        final rebuilds = _eventLog.where((event) =>
            event.type == 'widget_rebuild' &&
            event.timestamp.difference(click.timestamp).inMilliseconds.abs() < 1000 &&
            event.timestamp.isAfter(click.timestamp)).length;

        if (rebuilds == 0) {
          final error = SemanticError(
            type: 'button_no_response',
            description: 'Button click at ${click.timestamp} did not trigger any state changes or widget rebuilds',
            suggestedFix: 'Check if the onPressed callback is properly implemented and not returning early',
            timestamp: click.timestamp,
            context: 'Button: ${click.data['widget_name'] ?? 'Unknown'}',
          );
          _errorController.add(error);
        }
      }
    }
  }

  Future<void> _analyzeStateManagementIssues() async {
    // Look for setState issues
    final setStateCalls = _eventLog.where((event) => event.type == 'set_state').toList();
    final rebuilds = _eventLog.where((event) => event.type == 'widget_rebuild').toList();

    for (final setState in setStateCalls) {
      // Check if setState is called too frequently (potential infinite loop)
      final sameWidgetSetStates = setStateCalls.where((call) =>
          call.timestamp.difference(setState.timestamp).inMilliseconds.abs() < 100 &&
          call.data['widget_name'] == setState.data['widget_name']).length;

      if (sameWidgetSetStates > 5) {
        final error = SemanticError(
          type: 'infinite_setstate',
          description: 'Potential infinite setState loop detected in ${setState.data['widget_name'] ?? 'Unknown widget'}',
          suggestedFix: 'Check if setState is being called inside build() method or if state changes are causing circular updates',
          timestamp: setState.timestamp,
          context: 'Multiple setState calls in quick succession',
        );
        _errorController.add(error);
      }

      // Check if setState doesn't trigger rebuild
      final hasRebuild = rebuilds.any((rebuild) =>
          rebuild.timestamp.difference(setState.timestamp).inMilliseconds.abs() < 500 &&
          rebuild.timestamp.isAfter(setState.timestamp) &&
          rebuild.data['widget_name'] == setState.data['widget_name']);

      if (!hasRebuild) {
        final error = SemanticError(
          type: 'setstate_no_rebuild',
          description: 'setState called on ${setState.data['widget_name'] ?? 'Unknown widget'} but no widget rebuild detected',
          suggestedFix: 'Check if the state being updated is actually used in the widget build method',
          timestamp: setState.timestamp,
          context: 'State update: ${setState.data['state_change'] ?? 'Unknown'}',
        );
        _errorController.add(error);
      }
    }
  }

  Future<void> _analyzeWidgetTreeIssues() async {
    // Look for widget tree problems
    final rebuilds = _eventLog.where((event) => event.type == 'widget_rebuild').toList();

    // Check for excessive rebuilds
    final widgetRebuildCounts = <String, int>{};
    for (final rebuild in rebuilds) {
      final widgetName = rebuild.data['widget_name'] ?? 'Unknown';
      widgetRebuildCounts[widgetName] = (widgetRebuildCounts[widgetName] ?? 0) + 1;
    }

    for (final entry in widgetRebuildCounts.entries) {
      if (entry.value > 20) { // More than 20 rebuilds in session
        final error = SemanticError(
          type: 'excessive_rebuilds',
          description: 'Widget ${entry.key} rebuilt ${entry.value} times - potential performance issue',
          suggestedFix: 'Consider using const widgets, memoization, or optimizing state management to reduce unnecessary rebuilds',
          timestamp: DateTime.now(),
          context: 'Widget rebuild count: ${entry.value}',
        );
        _errorController.add(error);
      }
    }

    // Check for deep widget trees (potential performance issue)
    final deepTrees = _eventLog.where((event) =>
        event.type == 'widget_build' &&
        (event.data['tree_depth'] as int? ?? 0) > 10).length;

    if (deepTrees > 0) {
      final error = SemanticError(
        type: 'deep_widget_tree',
        description: 'Detected $deepTrees widget builds with tree depth > 10 - potential performance issue',
        suggestedFix: 'Consider flattening widget tree or using more efficient widget composition',
        timestamp: DateTime.now(),
        context: 'Deep widget tree detected',
      );
      _errorController.add(error);
    }
  }

  Future<void> _analyzeLogicFlowIssues() async {
    // Look for logic flow problems
    final ifConditions = _eventLog.where((event) => event.type == 'if_condition').toList();
    final returns = _eventLog.where((event) => event.type == 'return_statement').toList();

    // Check for unreachable code patterns
    for (int i = 0; i < ifConditions.length - 1; i++) {
      final current = ifConditions[i];
      final next = ifConditions[i + 1];

      if (next.timestamp.difference(current.timestamp).inMilliseconds < 100) {
        // Two if conditions very close together might indicate unreachable code
        final error = SemanticError(
          type: 'potential_unreachable_code',
          description: 'Potential unreachable code detected near ${current.timestamp}',
          suggestedFix: 'Review conditional logic to ensure all branches are reachable',
          timestamp: current.timestamp,
          context: 'Multiple rapid conditional checks detected',
        );
        _errorController.add(error);
      }
    }

    // Check for missing return statements in async functions
    final asyncCalls = _eventLog.where((event) => event.type == 'async_call').toList();
    for (final asyncCall in asyncCalls) {
      final hasReturn = returns.any((r) =>
          r.timestamp.isAfter(asyncCall.timestamp) &&
          r.timestamp.difference(asyncCall.timestamp).inMilliseconds < 5000);

      if (!hasReturn && asyncCall.data['function_type'] == 'async') {
        final error = SemanticError(
          type: 'missing_return',
          description: 'Async function ${asyncCall.data['function_name'] ?? 'Unknown'} may be missing return statement',
          suggestedFix: 'Ensure async function returns a value or Future',
          timestamp: asyncCall.timestamp,
          context: 'Async function: ${asyncCall.data['function_name'] ?? 'Unknown'}',
        );
        _errorController.add(error);
      }
    }
  }

  // Helper methods for recording different types of events
  void recordButtonClick(String widgetName, String? action) {
    addEvent(SemanticEvent(
      type: 'button_click',
      timestamp: DateTime.now(),
      data: {
        'widget_name': widgetName,
        'action': action,
      },
    ));
  }

  void recordStateChange(String widgetName, String stateChange) {
    addEvent(SemanticEvent(
      type: 'state_change',
      timestamp: DateTime.now(),
      data: {
        'widget_name': widgetName,
        'state_change': stateChange,
      },
    ));
  }

  void recordSetState(String widgetName, String stateChange) {
    addEvent(SemanticEvent(
      type: 'set_state',
      timestamp: DateTime.now(),
      data: {
        'widget_name': widgetName,
        'state_change': stateChange,
      },
    ));
  }

  void recordWidgetRebuild(String widgetName, int treeDepth) {
    addEvent(SemanticEvent(
      type: 'widget_rebuild',
      timestamp: DateTime.now(),
      data: {
        'widget_name': widgetName,
        'tree_depth': treeDepth,
      },
    ));
  }

  void recordWidgetBuild(String widgetName, int treeDepth) {
    addEvent(SemanticEvent(
      type: 'widget_build',
      timestamp: DateTime.now(),
      data: {
        'widget_name': widgetName,
        'tree_depth': treeDepth,
      },
    ));
  }

  void recordIfCondition(String condition, bool result) {
    addEvent(SemanticEvent(
      type: 'if_condition',
      timestamp: DateTime.now(),
      data: {
        'condition': condition,
        'result': result,
      },
    ));
  }

  void recordReturnStatement(String function, dynamic value) {
    addEvent(SemanticEvent(
      type: 'return_statement',
      timestamp: DateTime.now(),
      data: {
        'function': function,
        'value': value?.toString() ?? 'null',
      },
    ));
  }

  void recordAsyncCall(String functionName, String functionType) {
    addEvent(SemanticEvent(
      type: 'async_call',
      timestamp: DateTime.now(),
      data: {
        'function_name': functionName,
        'function_type': functionType,
      },
    ));
  }

  void clearEventLog() {
    _eventLog.clear();
    print('🔍 Semantic Analysis: Event log cleared');
  }

  void dispose() {
    _errorController.close();
    _recordingController.close();
    _isRecording = false;
    _isAnalyzing = false;
    _eventLog.clear();
  }

  // ENHANCED: Stream for event log updates
  Stream<List<SemanticEvent>> get eventLogStream => _eventLogController.stream;

  // ENHANCED: Controller for event log stream
  final StreamController<List<SemanticEvent>> _eventLogController = StreamController<List<SemanticEvent>>.broadcast();
}

class SemanticEvent {
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  SemanticEvent({
    required this.type,
    required this.timestamp,
    required this.data,
  });
}
