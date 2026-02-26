import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/bridge_service.dart';
import '../services/terminal_service.dart';
import '../services/ai_service.dart';
import '../services/scanner_service.dart';
import '../services/android_bridge_service.dart';
import '../services/semantic_analyzer_service.dart';
import '../services/resource_guard_service.dart';
import '../widgets/health_monitor.dart';
import '../widgets/knowledge_graph_view_enhanced.dart';
import '../widgets/fix_preview_panel.dart';
import 'settings_screen.dart';
import '../widgets/error_badge.dart';
import '../widgets/file_inspector.dart';
import '../widgets/status_bar.dart';
import '../widgets/activity_log.dart';
import '../services/error_classifier.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final BridgeService _bridgeService = BridgeService();
  final TerminalService _terminalService = TerminalService();
  final AiService _aiService = AiService();
  bool _isServerRunning = false;
  String _connectionStatus = 'Disconnected';
  ErrorMessage? _lastError;
  bool _hasError = false;
  bool _isAiThinking = false;
  bool _isFixApplied = false;
  Map<String, dynamic>? _currentFix;

  // Build phase state management
  bool _isBuildPhase = false; // Start in runtime phase (app is already running)
  bool _isBuilding = false;
  String _buildStatus = 'Ready to build';
  List<Map<String, dynamic>> _lintIssues = [];
  Map<String, List<Map<String, dynamic>>> _lintMap = {};

  // Auto-fix mode toggle
  bool _autoFixEnabled = true; // Default to auto-fix enabled

  // Knowledge Graph state
  final ScannerService _scannerService = ScannerService();
  final AndroidBridgeService _androidBridgeService = AndroidBridgeService();
  final SemanticAnalyzerService _semanticAnalyzerService = SemanticAnalyzerService();
  final ResourceGuardService _resourceGuardService = ResourceGuardService();
  ProjectMap? _currentProjectMap;
  bool _showKnowledgeGraph = false; // Toggle between dashboard and knowledge graph
  List<String> _errorFiles = []; // Files with active errors for pulsing

  @override
  void initState() {
    super.initState();
    _startServer();
    _startAndroidBridge();
    _setupErrorListener();
    _setupAiFixListener();
    _setupLogListener();
    _setupConfirmationListener();
    _setupSemanticErrorListener();
    _setupLintListener();
    // Prompt for API key if missing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = AiService().apiKey;
      if (key == null || key.isEmpty) {
        _showApiKeyPrompt();
      }
    });
    // NOTE: Do NOT call _startMonitoring() here - the app is already running via flutter run
    // Spawning another flutter run process causes port conflicts. The app receives errors
    // directly from the running Flutter process via other means.
  }

  void _setupLintListener() {
    _scannerService.lintStream.listen((issues) {
      // issues: List<Map<String,dynamic>> with keys 'file','line','message'
      final parsed = <Map<String, dynamic>>[];
      final files = <String>{};
      final map = <String, List<Map<String, dynamic>>>{};
      for (final i in issues) {
        try {
          final file = i['file']?.toString() ?? '';
          final line = i['line'] is int ? i['line'] as int : int.tryParse(i['line']?.toString() ?? '') ?? 0;
          final message = i['message']?.toString() ?? '';
          final entry = {'file': file, 'line': line, 'message': message};
          parsed.add(entry);
          // normalize for errorFiles: use path's basename or relative path
          final base = file.split(Platform.pathSeparator).last;
          files.add(base);
          map.putIfAbsent(base, () => []).add(entry);
        } catch (e) {
          // ignore parse errors
        }
      }

      if (mounted) {
        setState(() {
          _lintIssues = parsed;
          // also update errorFiles so graph can pulse nodes
          _errorFiles = files.toList();
          _lintMap = map;
        });
      }
    });
  }

  void _showApiKeyPrompt() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('OraFlow API Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your Groq/Ollama API key to enable AI features.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Enter API key',
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () {
                final key = controller.text.trim();
                if (key.isNotEmpty) {
                  AiService().updateApiKey(key);
                }
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startServer() async {
    try {
      await _bridgeService.startServer();
      setState(() {
        _isServerRunning = true;
        _connectionStatus = 'Server Running - Waiting for VS Code';
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Failed to start server: $e';
      });
    }
  }

  Future<void> _startAndroidBridge() async {
    try {
      await _androidBridgeService.startServer();
      print('Android Bridge WebSocket server started');
      
      // Setup Android error listener
      _androidBridgeService.androidErrorStream.listen((androidError) {
        print('📱 Android error received: ${androidError['error_type']}');
        
        // Handle Android error via TerminalService
        _terminalService.handleAndroidError(androidError);
        
        // Show notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📱 Android error detected: ${androidError['error_type']}'),
            backgroundColor: Colors.orange,
          ),
        );
      });
      
    } catch (e) {
      print('Failed to start Android Bridge: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start Android Bridge: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _setupErrorListener() {
    _terminalService.errorStream.listen((error) {
      // PHASE 2: UI STATE PROTECTION - Handle errors with timeout protection
      _handleIncomingError(error);
    });
  }

  void _handleIncomingError(ErrorMessage error) async {
    // Update error files list for knowledge graph pulsing
    final errorFile = error.filePath.split('/').last;
    if (!_errorFiles.contains(errorFile)) {
      _errorFiles.add(errorFile);
    }

    setState(() {
      _lastError = error;
      _hasError = true;
      _isAiThinking = true;
    });

    // Send error to VS Code for processing
    _bridgeService.sendMessage({
      'type': 'error_detected',
      'error': error.toJson(),
    });

    // PHASE 2: PROTECTOR - If AI takes > 12 seconds, force-stop the spinner
    Timer(const Duration(seconds: 12), () {
      if (mounted && _isAiThinking) {
        setState(() {
          _isAiThinking = false;
          // Show timeout message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CTO consultation timed out. Please try again.')),
          );
        });
      }
    });

    try {
      // PHASE 2: Generate preview first, send to VS Code for user acceptance
      final preview = await _aiService.previewFix(error.errorMessage, error.filePath, error.line, isBuildError: true);

      if (mounted) {
        setState(() {
          _isAiThinking = false;
          _currentFix = preview;
        });

        if (preview != null && preview['preview_available'] == true) {
          // Send preview to VS Code extension for side-by-side review
          _bridgeService.sendMessage(preview);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI could not generate a preview for the fix.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAiThinking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI error: $e')),
        );
      }
    }
  }

  void _setupAiFixListener() {
    _terminalService.aiFixStream.listen((fix) {
      setState(() {
        _isAiThinking = false;
        _currentFix = fix;
      });
    });
  }

  void _setupLogListener() {
    _terminalService.logStream.listen((log) {
      setState(() {}); // Update UI when new logs arrive
    });
  }

  void _setupConfirmationListener() {
    _bridgeService.confirmationStream.listen((confirmation) {
      print('🎯 Fix confirmation received from VS Code!');

      // Trigger cooldown in terminal service to prevent repeated error detection
      _terminalService.applyCooldown();

      // Check if this was a build error - if so, no need to restart (app is already running)
      // Removed: auto-restart monitoring causes port conflicts
      final wasBuildError = confirmation['wasBuildError'] == true || _isBuildPhase;
      if (wasBuildError) {
        print('✅ Build error fixed - monitoring continues in existing Flutter process');
      }

      // UNLOCK the terminal service so it can listen for new errors
      _terminalService.unlock();

      // Reset UI state to show success
      setState(() {
        _hasError = false;
        _lastError = null;
        _currentFix = null;
        _isAiThinking = false;
        _isFixApplied = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Fix confirmed and applied successfully!')),
      );
    });
  }

  void _setupSemanticErrorListener() {
    _semanticAnalyzerService.semanticErrorStream.listen((semanticError) async {
      print('🔍 Semantic Error detected: ${semanticError.type} - ${semanticError.description}');
      
      // Show notification about semantic error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔍 Semantic error: ${semanticError.type}'),
          backgroundColor: Colors.purple,
        ),
      );

      // Handle semantic error via AI service
      try {
        final fix = await _aiService.handleSemanticError(semanticError);
        
        if (fix != null) {
          setState(() {
            _currentFix = fix;
            _isAiThinking = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🔍 Semantic error fix generated!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🔍 Could not generate fix for semantic error')),
          );
        }
      } catch (e) {
        print('❌ Semantic error handling failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Semantic error analysis failed: $e')),
        );
      }
    });
  }

  void _testConnection() {
    if (_bridgeService.isRunning) {
      _bridgeService.sendPing();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ping sent to VS Code!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server not running')),
      );
    }
  }

  Future<void> _startMonitoring() async {
    try {
      // Ensure a project was selected
      if (_terminalService.projectRoot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Please select a project first using the project picker!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Start all monitoring services together for seamless experience
      await _terminalService.startMonitoring();
      
      // Auto-start Resource Guard for RAM management
      if (!_resourceGuardService.isMonitoring) {
        _resourceGuardService.startMonitoring();
      }
      
      // Auto-start Semantic Analysis for code pattern monitoring
      if (!_semanticAnalyzerService.isRecording) {
        _semanticAnalyzerService.startRecording();
      }

      setState(() {}); // Force UI update
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🚀 All monitoring services started! (Terminal + Resource Guard + Semantic Analysis)')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start monitoring: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopMonitoring() async {
    await _terminalService.stopMonitoring();
    setState(() {
      _hasError = false;
      _lastError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shadow Terminal monitoring stopped')),
    );
  }

  void _dismissError() {
    setState(() {
      _hasError = false;
      _lastError = null;
      _currentFix = null;
      _isAiThinking = false;
    });
  }

  Future<void> _testAiConnection() async {
    setState(() {
      _isAiThinking = true;
    });

    try {
      // Test with a simple prompt - use a real file path
      final testErrorLog = 'Test error: Variable x is null';
        final testFilePath = _terminalService.projectRoot != null
          ? (_terminalService.projectRoot! + Platform.pathSeparator + 'lib' + Platform.pathSeparator + 'main.dart')
          : Directory.current.path + Platform.pathSeparator + 'lib' + Platform.pathSeparator + 'main.dart';

      // Add 10-second timeout to prevent hanging
      final fixResult = await _aiService.getFix(testErrorLog, testFilePath, 6).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('AI request timed out');
          return null;
        },
      );

      // Convert Map to FixAction if successful
      FixAction? fixAction;
      if (fixResult != null && !fixResult.containsKey('error')) {
        try {
          fixAction = FixAction.fromJson(fixResult);
        } catch (e) {
          print('Failed to parse test fix result: $e');
        }
      }

      setState(() {
        _isAiThinking = false;
        _currentFix = fixResult;
        if (fixResult != null && !fixResult.containsKey('error')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI connection successful!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI responded but no fix generated')),
          );
        }
      });
    } catch (e) {
      setState(() {
        _isAiThinking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI connection failed: $e')),
      );
    }
  }

  void _applyFix(FixAction fix) {
    // Send each edit to VS Code
    for (final edit in fix.edits) {
      _bridgeService.sendMessage({
        'command': 'apply_edit',
        'file': edit.file,
        'line': edit.line,
        'oldText': edit.oldLineContent,
        'newText': edit.newLineContent,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fix applied to VS Code! 🚀')),
    );
  }

  void _applyFixToVSCode(Map<String, dynamic> fix) {
    // Send the apply_edit command to VS Code
    // Handle preview payloads where the actual AI result may be under `original_fix`
    Map<String, dynamic>? aiResult = fix;
    if (fix.containsKey('original_fix') && fix['original_fix'] is Map<String, dynamic>) {
      aiResult = Map<String, dynamic>.from(fix['original_fix'] as Map<String, dynamic>);
    }

    final editsRaw = aiResult != null ? aiResult['edits'] : null;
    if (editsRaw == null || editsRaw is! List) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No edits found in AI result — cannot apply fix')),
      );
      print('⚠️ _applyFixToVSCode: edits missing or invalid: $editsRaw');
      return;
    }

    for (final edit in editsRaw) {
      if (edit == null) continue;
      final editMap = edit as Map<String, dynamic>;

      // Resolve file path: prefer absolute path from edit, else derive from project root
      String filePath = editMap['file']?.toString() ?? '';
      if (filePath.isEmpty) {
        // try to resolve using terminalService.projectRoot + file (if relative)
        final pr = _terminalService.projectRoot ?? Directory.current.path;
        filePath = pr + Platform.pathSeparator + (editMap['file']?.toString() ?? '');
      }

      _bridgeService.sendMessage({
        'type': 'apply_edit',
        'command': 'apply_edit',
        'file': filePath,
        'line': editMap['line'],
        'oldText': editMap['old_line_content'],
        'newText': editMap['new_line_content'],
      });

      print('🚀 Sent fix command to VS Code for file $filePath line ${editMap['line']}: ${editMap['new_line_content']}');
    }

    // Clear terminal to remove old error logs
    _terminalService.sendInput('c');

    // Trigger hot reload to apply changes immediately
    Future.delayed(const Duration(milliseconds: 500), () {
      _terminalService.sendInput('r');
    });

    // Note: UI state will be updated when confirmation is received from VS Code
    // via _setupConfirmationListener

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fix sent to VS Code - awaiting confirmation...')),
    );
  }

  Future<void> _selectProject() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      _terminalService.setProjectRoot(result);

      // Scan the project for knowledge graph
      try {
        _currentProjectMap = await _scannerService.scanProject(result);
        setState(() {});
        print('📊 Knowledge graph scanned: ${_currentProjectMap?.nodes.length} files, ${_currentProjectMap?.edges.length} connections');
      } catch (e) {
        print('❌ Failed to scan project: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Project set to: $result')),
      );
    }
  }

  Widget _buildStatusCard() {
    if (_isFixApplied) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: const Text(
                      '✅ FIX APPLIED SUCCESSFULLY!',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isFixApplied = false;
                        _hasError = false;
                        _lastError = null;
                        _currentFix = null;
                        _isAiThinking = false;
                      });
                    },
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Code has been automatically fixed in VS Code! 🎉',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_hasError && _lastError != null) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _currentFix != null
              ? const Color(0xFF00F5FF).withOpacity(0.1) // Cyan for fix ready
              : const Color(0xFFFF3131).withOpacity(0.1), // Red for error
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _currentFix != null ? const Color(0xFF00F5FF) : const Color(0xFFFF3131),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _currentFix != null ? Icons.lightbulb : Icons.error_outline,
                      key: ValueKey(_currentFix != null),
                      color: _currentFix != null ? const Color(0xFF00F5FF) : const Color(0xFFFF3131),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_lastError != null)
                    ErrorIndicator(
                      errorMessage: _lastError!.errorMessage,
                      isBuildError: _isBuildPhase,
                      showType: true,
                      showSeverity: true,
                      showCompact: false,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        color: _currentFix != null ? const Color(0xFF00F5FF) : const Color(0xFFFF3131),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      child: Text(
                        _currentFix != null
                            ? '🚀 ORAFLOW FIX READY'
                            : 'Crash detected in ${_lastError!.filePath.split('/').last} at line ${_lastError!.line}',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _dismissError,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Show different content based on state
              _buildContentWidget(),
            ],
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildContentWidget() {
    if (_isAiThinking) {
      // Thinking state
      return Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF00F5FF),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'OraFlow is consulting the CTO Agent...',
            style: TextStyle(
              color: Color(0xFF00F5FF),
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    } else if (_currentFix != null) {
      // Fix ready state
      final explanation = _extractExplanationFromFix(_currentFix!);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            explanation.isNotEmpty ? explanation : 'No explanation provided.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // Preview and Apply Fix Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Preview Button
              _buildHoverButton(
                label: 'Preview Fix',
                icon: Icons.visibility,
                onPressed: () => _showFixPreview(_currentFix!),
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
              ),
              const SizedBox(width: 12),
              // Apply Fix Button
              _buildHoverButton(
                label: 'Apply Fix',
                icon: Icons.build,
                onPressed: () => _applyFixToVSCode(_currentFix!),
                backgroundColor: const Color(0xFF00F5FF),
                foregroundColor: const Color(0xFF0B0E14),
              ),
            ],
          ),
        ],
      );
    } else {
      // Error state (no fix found)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analyzing error: ${_lastError!.errorMessage}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI could not generate a fix for this error.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Toggle between dashboard and knowledge graph view
    if (_showKnowledgeGraph && _currentProjectMap != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0E14),
        appBar: AppBar(
          title: const Text(
            'Code Galaxy - Knowledge Graph',
            style: TextStyle(color: Color(0xFF00F5FF)),
          ),
          backgroundColor: const Color(0xFF0B0E14),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF00F5FF)),
            onPressed: () {
              setState(() {
                _showKnowledgeGraph = false;
              });
            },
          ),
        ),
        body: Stack(
          children: [
            KnowledgeGraphView(
              projectMap: _currentProjectMap!,
              errorFiles: _errorFiles,
              lintMap: _lintMap,
              onOpenFile: (file, line) {
                _bridgeService.sendMessage({ 'type': 'open_file', 'file': file, 'line': line });
              },
            ),
            // Health Monitor in bottom left
            Positioned(
              bottom: 20,
              left: 20,
              child: const HealthMonitor(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14), // Deep Space
      appBar: AppBar(
        title: const Text(
          'OraFlow Dashboard',
          style: TextStyle(color: Color(0xFF00F5FF)), // Electric Cyan
        ),
        backgroundColor: const Color(0xFF0B0E14),
        elevation: 0,
        actions: [
          // Lint summary action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextButton.icon(
              onPressed: () {
                _showLintList();
              },
              icon: const Icon(Icons.rule, color: Color(0xFF00F5FF)),
              label: Text(
                '${_lintIssues.length}',
                style: const TextStyle(color: Color(0xFF00F5FF)),
              ),
            ),
          ),
          // Knowledge Graph Toggle Button
          IconButton(
            icon: const Icon(Icons.scatter_plot, color: Color(0xFF00F5FF)),
            tooltip: 'View Knowledge Graph',
            onPressed: _currentProjectMap != null
                ? () {
                    setState(() {
                      _showKnowledgeGraph = true;
                    });
                  }
                : null,
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF00F5FF)),
            tooltip: 'Settings',
            onPressed: () async {
              // Navigate to settings screen
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0E14),
          // Subtle gradient overlay for depth
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0B0E14),
              const Color(0xFF0B0E14).withOpacity(0.95),
              const Color(0xFF1a1d23).withOpacity(0.3),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Health Monitor in bottom left
            Positioned(
              bottom: 20,
              left: 20,
              child: const HealthMonitor(),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // System Health Indicator
                Card(
                  color: const Color(0xFF1a1d23),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0), // Reduced from 16.0
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          child: Icon(
                            _isBuildPhase
                                ? (_isBuilding ? Icons.build : Icons.build_circle)
                                : (_terminalService.isMonitoring
                                    ? (_hasError ? Icons.heart_broken : Icons.favorite)
                                    : Icons.heart_broken_outlined),
                            color: _hasError
                                ? const Color(0xFFFF3131) // Neon Red
                                : (_isBuildPhase
                                    ? (_isBuilding ? Colors.orange : Colors.yellow)
                                    : (_terminalService.isMonitoring ? Colors.green : Colors.grey)),
                            size: 24, // Reduced from 32
                          ),
                        ),
                        const SizedBox(width: 8), // Reduced from 16
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isBuildPhase ? 'Pre-Flight Status' : 'System Health',
                                style: const TextStyle(
                                  color: Color(0xFF00F5FF),
                                  fontSize: 14, // Reduced from 18
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _isBuildPhase
                                    ? (_isBuilding ? '🔨 Building...' : _buildStatus)
                                    : (_hasError
                                        ? '🚨 Error Detected!'
                                        : (_terminalService.isMonitoring
                                            ? '✅ Runtime Monitoring Active'
                                            : '⏸️  Monitoring Inactive')),
                                style: TextStyle(
                                  color: _hasError ? const Color(0xFFFF3131) : Colors.white,
                                  fontSize: 12, // Reduced from 14
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Status Card
                _buildStatusCard(),

                // Settings Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Auto-fix Toggle
                    Row(
                      children: [
                        const Text(
                          'Auto-Fix Mode',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _autoFixEnabled,
                          onChanged: (value) {
                            setState(() {
                              _autoFixEnabled = value;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Auto-fix ${value ? 'enabled' : 'disabled'}')),
                            );
                          },
                          activeColor: const Color(0xFF00F5FF),
                          activeTrackColor: const Color(0xFF00F5FF).withOpacity(0.3),
                        ),
                      ],
                    ),
                    const SizedBox(width: 40),
                    // Project Selection
                    ElevatedButton.icon(
                      onPressed: _selectProject,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Select Project'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00F5FF),
                        foregroundColor: const Color(0xFF0B0E14),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Monitoring Controls
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _terminalService.isMonitoring ? null : _startMonitoring,
                        icon: const Icon(Icons.visibility),
                        label: const Text('Start Monitoring'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _terminalService.isMonitoring ? _stopMonitoring : null,
                        icon: const Icon(Icons.visibility_off),
                        label: const Text('Stop Monitoring'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Emergency Reset Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _terminalService.emergencyReset();
                          setState(() {
                            _hasError = false;
                            _lastError = null;
                            _currentFix = null;
                            _isAiThinking = false;
                            _isFixApplied = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('🚨 Emergency reset applied - all locks cleared')),
                          );
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Engine'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Compact Controls Row - Semantic Analysis + Resource Guard
                Row(
                  children: [
                    // Semantic Analysis (Compact)
                    Expanded(
                      child: Card(
                        color: const Color(0xFF1a1d23),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Semantic Analysis',
                                style: TextStyle(
                                  color: Color(0xFF00F5FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _semanticAnalyzerService.isRecording
                                        ? null
                                        : () {
                                            _semanticAnalyzerService.startRecording();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('🔍 Recording started'),
                                                backgroundColor: Colors.blue,
                                              ),
                                            );
                                          },
                                    icon: const Icon(Icons.fiber_manual_record, size: 16),
                                    label: const Text('Record', style: TextStyle(fontSize: 10)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _semanticAnalyzerService.isRecording
                                          ? Colors.grey
                                          : Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton.icon(
                                    onPressed: _semanticAnalyzerService.isRecording
                                        ? () {
                                            _semanticAnalyzerService.stopRecording();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('🔍 Recording stopped'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        : null,
                                    icon: const Icon(Icons.stop, size: 16),
                                    label: const Text('Stop', style: TextStyle(fontSize: 10)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _semanticAnalyzerService.isRecording
                                          ? Colors.green
                                          : Colors.grey,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _semanticAnalyzerService.isRecording
                                          ? Colors.red
                                          : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _semanticAnalyzerService.isRecording
                                        ? 'Recording'
                                        : 'Ready',
                                    style: TextStyle(
                                      color: _semanticAnalyzerService.isRecording
                                          ? Colors.red
                                          : Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Events: ${_semanticAnalyzerService.eventLog.length}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Resource Guard (Compact)
                    Expanded(
                      child: Card(
                        color: const Color(0xFF1a1d23),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Resource Guard',
                                style: TextStyle(
                                  color: Color(0xFF00F5FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _resourceGuardService.isMonitoring
                                        ? null
                                        : () {
                                            _resourceGuardService.startMonitoring();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('🛡️ Monitoring started'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          },
                                    icon: const Icon(Icons.shield, size: 16),
                                    label: const Text('Start', style: TextStyle(fontSize: 10)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _resourceGuardService.isMonitoring
                                          ? Colors.grey
                                          : Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton.icon(
                                    onPressed: _resourceGuardService.isMonitoring
                                        ? () {
                                            _resourceGuardService.stopMonitoring();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('🛡️ Monitoring stopped'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        : null,
                                    icon: const Icon(Icons.shield_outlined, size: 16),
                                    label: const Text('Stop', style: TextStyle(fontSize: 10)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _resourceGuardService.isMonitoring
                                          ? Colors.red
                                          : Colors.grey,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _resourceGuardService.isMonitoring
                                          ? Colors.green
                                          : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _resourceGuardService.isMonitoring
                                        ? 'Active'
                                        : 'Inactive',
                                    style: TextStyle(
                                      color: _resourceGuardService.isMonitoring
                                          ? Colors.green
                                          : Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'AI: ${_resourceGuardService.concurrentAiRequests}/2',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Terminal Controls and View (Scrollable)
                Expanded(
                  child: Card(
                    color: const Color(0xFF1a1d23),
                    child: Column(
                      children: [
                        // Terminal Header with Controls
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF15181E),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            border: Border(
                              bottom: BorderSide(color: const Color(0xFF00F5FF).withOpacity(0.3)),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Window Controls
                              Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.yellow,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Shadow Terminal',
                                style: TextStyle(
                                  color: Color(0xFF00F5FF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              // Terminal Actions
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      _terminalService.sendInput('c');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Terminal cleared')),
                                      );
                                    },
                                    icon: const Icon(Icons.clear, color: Color(0xFF00F5FF)),
                                    tooltip: 'Clear Terminal',
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _terminalService.sendInput('r');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Hot reload triggered')),
                                      );
                                    },
                                    icon: const Icon(Icons.refresh, color: Color(0xFF00F5FF)),
                                    tooltip: 'Hot Reload',
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _terminalService.sendInput('R');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Full restart triggered')),
                                      );
                                    },
                                    icon: const Icon(Icons.restart_alt, color: Color(0xFF00F5FF)),
                                    tooltip: 'Full Restart',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Terminal Content - Scrollable
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B0E14),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                            ),
                            child: Column(
                              children: [
                                // Terminal Status Bar
                                Container(
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF11141A),
                                    border: Border(
                                      bottom: BorderSide(color: const Color(0xFF00F5FF).withOpacity(0.3)),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _terminalService.isMonitoring
                                                ? Colors.green
                                                : Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _terminalService.isMonitoring
                                              ? 'Monitoring Active'
                                              : 'Monitoring Inactive',
                                          style: TextStyle(
                                            color: _terminalService.isMonitoring
                                                ? Colors.green
                                                : Colors.red,
                                            fontSize: 10,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Lines: ${_terminalService.recentLogs.length}',
                                          style: const TextStyle(
                                            color: Color(0xFF00F5FF),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Terminal Log Area - Scrollable
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ListView.builder(
                                      reverse: true, // Show latest logs at bottom
                                      itemCount: _terminalService.recentLogs.length,
                                      itemBuilder: (context, index) {
                                        final log = _terminalService.recentLogs[_terminalService.recentLogs.length - 1 - index];
                                        final isError = log.contains('[ERROR]') ||
                                                       log.contains('Exception') ||
                                                       log.contains('Error');
                                        return Text(
                                          log,
                                          style: TextStyle(
                                            color: isError ? const Color(0xFFFF3131) : Colors.white70,
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Test Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _testAiConnection,
                        icon: const Icon(Icons.psychology),
                        label: const Text('Test AI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F5FF),
                          foregroundColor: const Color(0xFF0B0E14),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _testConnection,
                        icon: const Icon(Icons.send),
                        label: const Text('Test Bridge'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Connection Status
                Card(
                  color: const Color(0xFF1a1d23),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VS Code Bridge',
                          style: TextStyle(
                            color: Color(0xFF00F5FF),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _connectionStatus,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }

  // Preview Fix Functionality
  void _showFixPreview(Map<String, dynamic> fix) {
    // Generate preview data
    final previewData = _generatePreviewData(fix);
    
    if (previewData != null) {
      // Show the preview dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1a1d23),
            title: Row(
              children: [
                const Icon(Icons.visibility, color: Color(0xFF667eea)),
                const SizedBox(width: 8),
                Text(
                  'Preview Fix - ${previewData['file_name']}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Container(
                    width: 900,
                    height: 520,
                    child: FixPreviewPanel(
                      edits: (previewData['original_fix'] != null && previewData['original_fix']['edits'] is List)
                          ? List<Map<String, dynamic>>.from(previewData['original_fix']['edits'] as List)
                          : (previewData['edits'] is List ? List<Map<String, dynamic>>.from(previewData['edits'] as List) : []),
                      onAcceptSelected: (selectedEdits) {
                        Navigator.of(context).pop();
                        if (selectedEdits.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No edits selected')),
                          );
                          return;
                        }

                        // Build a minimal fix map with only selected edits and apply
                        final partialFix = {
                          'original_fix': {
                            'edits': selectedEdits,
                          }
                        };

                        _applyFixToVSCode(partialFix);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Selected edits sent to VS Code')),
                        );
                      },
                      onReject: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fix preview rejected')),
                        );
                      },
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
            ],
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not generate preview for this fix')),
      );
    }
  }

  String _getSeverity(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('error') || lower.contains('exception')) return 'error';
    if (lower.contains('warning') || lower.contains('deprecated')) return 'warning';
    return 'info';
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'error':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  // Helper: create a hover-enabled button with smooth scale animation
  Widget _buildHoverButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    Color backgroundColor = const Color(0xFF00F5FF),
    Color foregroundColor = const Color(0xFF0B0E14),
  }) {
    return StatefulBuilder(
      builder: (ctx, setState) {
        bool isHovering = false;
        return MouseRegion(
          onEnter: (_) => setState(() => isHovering = true),
          onExit: (_) => setState(() => isHovering = false),
          child: AnimatedScale(
            scale: isHovering ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: isHovering ? backgroundColor.withOpacity(0.9) : backgroundColor,
                foregroundColor: foregroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLintList() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1a1d23),
          title: Row(
            children: [
              const Icon(Icons.rule, color: Color(0xFF00F5FF)),
              const SizedBox(width: 8),
              Text('Lint Issues (${_lintIssues.length})', style: const TextStyle(color: Colors.white)),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 400,
            child: _lintIssues.isEmpty
                ? const Center(child: Text('No lint issues', style: TextStyle(color: Colors.white70)))
                : ListView.builder(
                    itemCount: _lintIssues.length,
                    itemBuilder: (ctx, idx) {
                      final it = _lintIssues[idx];
                      final file = it['file']?.toString() ?? '';
                      final line = it['line']?.toString() ?? '';
                      final msg = it['message']?.toString() ?? '';
                      final severity = _getSeverity(msg);
                      final severityColor = _getSeverityColor(severity);

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: severityColor.withOpacity(0.3)),
                        ),
                        child: ListTile(
                          leading: Icon(_getSeverityIcon(severity), color: severityColor, size: 20),
                          title: Text('$file:$line', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                          subtitle: Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: severityColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(severity.toUpperCase(), style: TextStyle(color: severityColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          onTap: () {
                            // Ask VS Code to open the file at line
                            _bridgeService.sendMessage({ 'type': 'open_file', 'file': file, 'line': it['line'] });
                            Navigator.of(context).pop();
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic>? _generatePreviewData(Map<String, dynamic> fix) {
    try {
      // Handle preview wrapper where AI result may be under `original_fix`
      Map<String, dynamic>? aiResult = fix;
      if (fix.containsKey('original_fix') && fix['original_fix'] is Map<String, dynamic>) {
        aiResult = Map<String, dynamic>.from(fix['original_fix'] as Map<String, dynamic>);
      }

      final editsRaw = aiResult != null ? aiResult['edits'] : null;
      if (editsRaw == null || editsRaw is! List) return null;

      if (editsRaw.isEmpty) return null;

      final edit = editsRaw[0] as Map<String, dynamic>;
      String editFile = edit['file']?.toString() ?? '';
      final editLine = (edit['line'] is int) ? edit['line'] as int : int.tryParse(edit['line']?.toString() ?? '') ?? 1;
      final oldContent = edit['old_line_content']?.toString() ?? '';
      final newContent = edit['new_line_content']?.toString() ?? '';

      // Resolve absolute path
      if (!editFile.contains(Platform.pathSeparator)) {
        final pr = _terminalService.projectRoot ?? Directory.current.path;
        editFile = pr + Platform.pathSeparator + editFile;
      }

      String beforeCode = oldContent.isNotEmpty ? oldContent : '/* No content */';
      try {
        final file = File(editFile);
        if (file.existsSync()) {
          final lines = file.readAsLinesSync();
          final start = (editLine - 5).clamp(0, lines.length - 1);
          final end = (editLine + 5).clamp(0, lines.length - 1);
          final snippet = lines.sublist(start, end + 1).join('\n');
          beforeCode = snippet;
        }
      } catch (e) {
        // ignore file read errors
      }

      final afterCode = newContent.isNotEmpty ? newContent : beforeCode;
      final changeDescription = _generateChangeDescription(oldContent, newContent);

      return {
        'file_name': editFile.split(Platform.pathSeparator).last,
        'file': editFile,
        'line_number': editLine,
        'before_code': beforeCode,
        'after_code': afterCode,
        'change_description': changeDescription,
        'original_fix': aiResult,
      };
    } catch (e) {
      print('Failed to generate preview data: $e');
      return null;
    }
  }

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

  String _extractExplanationFromFix(Map<String, dynamic> fix) {
    try {
      if (fix.containsKey('explanation') && (fix['explanation']?.toString().isNotEmpty ?? false)) {
        return fix['explanation'].toString();
      }
      if (fix.containsKey('original_fix') && fix['original_fix'] is Map<String, dynamic>) {
        final of = fix['original_fix'] as Map<String, dynamic>;
        if (of.containsKey('explanation') && (of['explanation']?.toString().isNotEmpty ?? false)) {
          return of['explanation'].toString();
        }
      }
    } catch (e) {
      // ignore
    }
    return '';
  }

  @override
  void dispose() {
    _bridgeService.stopServer();
    super.dispose();
  }
}
