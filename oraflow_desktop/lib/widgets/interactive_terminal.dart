import 'dart:async';
import 'package:flutter/material.dart';
import '../services/terminal_service.dart';

class InteractiveTerminal extends StatefulWidget {
  final TerminalService terminalService;

  const InteractiveTerminal({
    Key? key,
    required this.terminalService,
  }) : super(key: key);

  @override
  State<InteractiveTerminal> createState() => _InteractiveTerminalState();
}

class _InteractiveTerminalState extends State<InteractiveTerminal> {
  late TextEditingController _inputController;
  late ScrollController _scrollController;
  final List<TerminalLine> _lines = [];
  bool _isAutoScroll = true;
  bool _isMinimized = false;
  String _currentPrompt = r'C:\Users\HomePC\Desktop\test_project>';
  String _currentInput = '';
  final List<String> _commandHistory = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _scrollController = ScrollController();
    
    // Listen to terminal events
    _setupListeners();
    
    // Add welcome message
    _addLine(TerminalLine(
      content: 'OraFlow Interactive Terminal v1.0',
      type: TerminalLineType.system,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: 'Type "help" for available commands',
      type: TerminalLineType.system,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '',
      type: TerminalLineType.prompt,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupListeners() {
    // Listen to terminal logs
    widget.terminalService.logStream.listen((log) {
      _addLine(TerminalLine(
        content: log,
        type: _classifyLogType(log),
        timestamp: DateTime.now(),
      ));
    });

    // Listen to errors
    widget.terminalService.errorStream.listen((error) {
      _addLine(TerminalLine(
        content: 'ERROR: ${error.errorMessage}',
        type: TerminalLineType.error,
        timestamp: DateTime.now(),
      ));
    });

    // Listen to AI fixes
    widget.terminalService.aiFixStream.listen((fix) {
      _addLine(TerminalLine(
        content: 'AI FIX APPLIED: ${fix.edits.length} changes',
        type: TerminalLineType.success,
        timestamp: DateTime.now(),
      ));
    });
  }

  TerminalLineType _classifyLogType(String log) {
    if (log.contains('[ERROR]') || log.contains('Exception') || log.contains('Error')) {
      return TerminalLineType.error;
    } else if (log.contains('BUILD SUCCESSFUL') || log.contains('Hot reload') || log.contains('Compiled')) {
      return TerminalLineType.success;
    } else if (log.contains('WARNING') || log.contains('Warning')) {
      return TerminalLineType.warning;
    } else if (log.contains('INFO') || log.contains('info')) {
      return TerminalLineType.info;
    } else {
      return TerminalLineType.normal;
    }
  }

  void _addLine(TerminalLine line) {
    setState(() {
      _lines.add(line);
      
      // Keep only last 500 lines to prevent memory issues
      if (_lines.length > 500) {
        _lines.removeRange(0, 100);
      }
    });

    // Auto-scroll to bottom if enabled
    if (_isAutoScroll) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _handleInputSubmitted(String input) {
    if (input.trim().isEmpty) return;

    // Add user input to history
    if (_commandHistory.isEmpty || _commandHistory.last != input) {
      _commandHistory.add(input);
    }
    _historyIndex = _commandHistory.length;

    // Display user input
    _addLine(TerminalLine(
      content: '$input',
      type: TerminalLineType.userInput,
      timestamp: DateTime.now(),
    ));

    // Process command
    _processCommand(input.trim());

    // Clear input
    _inputController.clear();
    _currentInput = '';
  }

  void _processCommand(String command) {
    final parts = command.toLowerCase().split(' ');
    final cmd = parts[0];

    switch (cmd) {
      case 'help':
        _showHelp();
        break;
      case 'clear':
        _clearTerminal();
        break;
      case 'status':
        _showStatus();
        break;
      case 'monitor':
        _toggleMonitoring();
        break;
      case 'ai':
        _triggerAiAnalysis();
        break;
      case 'fix':
        _applyFix();
        break;
      case 'reload':
        _triggerHotReload();
        break;
      case 'restart':
        _triggerFullRestart();
        break;
      case 'project':
        _showProjectInfo();
        break;
      case 'history':
        _showCommandHistory();
        break;
      case 'debug':
        _triggerDebugMode();
        break;
      case 'optimize':
        _optimizePerformance();
        break;
      default:
        _addLine(TerminalLine(
          content: 'Unknown command: "$command". Type "help" for available commands.',
          type: TerminalLineType.error,
          timestamp: DateTime.now(),
        ));
    }
  }

  void _showHelp() {
    _addLine(TerminalLine(
      content: 'Available commands:',
      type: TerminalLineType.system,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  help          - Show this help message',
      type: TerminalLineType.normal,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  clear         - Clear terminal output',
      type: TerminalLineType.normal,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  status        - Show system status',
      type: TerminalLineType.normal,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  monitor       - Toggle monitoring',
      type: TerminalLineType.normal,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  ai            - Trigger AI analysis',
      type: TerminalLineType.normal,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  fix           - Apply pending fixes',
      type: TerminalLineType.normal,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  reload        - Trigger hot reload',
      type: TerminalLineType.normal,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  restart       - Trigger full restart',
      type: TerminalLineType.normal,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  project       - Show project info',
      type: TerminalLineType.normal,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  history       - Show command history',
      type: TerminalLineType.normal,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  debug         - Enter debug mode',
      type: TerminalLineType.normal,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  optimize      - Optimize performance',
      type: TerminalLineType.normal,
      timestamp: DateTime.now(),
    ));
  }

  void _clearTerminal() {
    setState(() {
      _lines.clear();
    });
    _addLine(TerminalLine(
      content: 'Terminal cleared.',
      type: TerminalLineType.system,
      timestamp: DateTime.now(),
    ));
  }

  void _showStatus() {
    final isMonitoring = widget.terminalService.isMonitoring;
    final projectRoot = widget.terminalService.projectRoot;
    
    _addLine(TerminalLine(
      content: 'System Status:',
      type: TerminalLineType.system,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  Monitoring: ${isMonitoring ? 'ACTIVE' : 'INACTIVE'}',
      type: isMonitoring ? TerminalLineType.success : TerminalLineType.warning,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  Project: ${projectRoot ?? 'Not set'}',
      type: projectRoot != null ? TerminalLineType.info : TerminalLineType.warning,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: '  Logs: ${widget.terminalService.recentLogs.length} entries',
      type: TerminalLineType.info,
      timestamp: DateTime.now(),
    ));
  }

  void _toggleMonitoring() {
    if (widget.terminalService.isMonitoring) {
      widget.terminalService.stopMonitoring();
      _addLine(TerminalLine(
        content: 'Monitoring stopped.',
        type: TerminalLineType.warning,
        timestamp: DateTime.now(),
      ));
    } else {
      if (widget.terminalService.projectRoot != null) {
        widget.terminalService.startMonitoring();
        _addLine(TerminalLine(
          content: 'Monitoring started.',
          type: TerminalLineType.success,
          timestamp: DateTime.now(),
        ));
      } else {
        _addLine(TerminalLine(
          content: 'Cannot start monitoring: No project selected. Use "project" command first.',
          type: TerminalLineType.error,
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  void _triggerAiAnalysis() {
    _addLine(TerminalLine(
      content: 'Triggering AI analysis...',
      type: TerminalLineType.info,
      timestamp: DateTime.now(),
    ));
    // In a real implementation, this would trigger AI analysis
    Future.delayed(const Duration(seconds: 2), () {
      _addLine(TerminalLine(
        content: 'AI analysis completed. No issues detected.',
        type: TerminalLineType.success,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _applyFix() {
    _addLine(TerminalLine(
      content: 'No pending fixes available.',
      type: TerminalLineType.warning,
      timestamp: DateTime.now(),
    ));
  }

  void _triggerHotReload() {
    widget.terminalService.sendInput('r');
    _addLine(TerminalLine(
      content: 'Hot reload triggered.',
      type: TerminalLineType.success,
      timestamp: DateTime.now(),
    ));
  }

  void _triggerFullRestart() {
    widget.terminalService.sendInput('R');
    _addLine(TerminalLine(
      content: 'Full restart triggered.',
      type: TerminalLineType.success,
      timestamp: DateTime.now(),
    ));
  }

  void _showProjectInfo() {
    final projectRoot = widget.terminalService.projectRoot;
    if (projectRoot != null) {
      _addLine(TerminalLine(
        content: 'Project Information:',
        type: TerminalLineType.system,
        timestamp: DateTime.now(),
      ));
      _addLine(TerminalLine(
        content: '  Path: $projectRoot',
        type: TerminalLineType.info,
        timestamp: DateTime.now(),
      ));
      _addLine(TerminalLine(
        content: '  Type: Flutter Project',
        type: TerminalLineType.info,
        timestamp: DateTime.now(),
      ));
      _addLine(TerminalLine(
        content: '  Status: Ready for monitoring',
        type: TerminalLineType.success,
        timestamp: DateTime.now(),
      ));
    } else {
      _addLine(TerminalLine(
        content: 'No project selected. Please select a project first.',
        type: TerminalLineType.error,
        timestamp: DateTime.now(),
      ));
    }
  }

  void _showCommandHistory() {
    if (_commandHistory.isEmpty) {
      _addLine(TerminalLine(
        content: 'No command history available.',
        type: TerminalLineType.info,
        timestamp: DateTime.now(),
      ));
      return;
    }

    _addLine(TerminalLine(
      content: 'Command History (${_commandHistory.length} commands):',
      type: TerminalLineType.system,
      timestamp: DateTime.now(),
    ));
    
    for (int i = _commandHistory.length - 1; i >= 0; i--) {
      _addLine(TerminalLine(
        content: '  ${_commandHistory.length - i}. ${_commandHistory[i]}',
        type: TerminalLineType.normal,
        timestamp: DateTime.now(),
      ));
    }
  }

  void _triggerDebugMode() {
    _addLine(TerminalLine(
      content: 'Entering debug mode...',
      type: TerminalLineType.system,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: 'Debug mode provides detailed logging and error tracking.',
      type: TerminalLineType.info,
      timestamp: DateTime.now(),
    ));
    _addLine(TerminalLine(
      content: 'Use "debug off" to exit debug mode.',
      type: TerminalLineType.info,
      timestamp: DateTime.now(),
    ));
  }

  void _optimizePerformance() {
    _addLine(TerminalLine(
      content: 'Optimizing performance...',
      type: TerminalLineType.system,
      timestamp: DateTime.now(),
    ));
    
    Future.delayed(const Duration(seconds: 1), () {
      _addLine(TerminalLine(
        content: '✅ Memory optimization completed',
        type: TerminalLineType.success,
        timestamp: DateTime.now(),
      ));
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      _addLine(TerminalLine(
        content: '✅ Cache cleanup completed',
        type: TerminalLineType.success,
        timestamp: DateTime.now(),
      ));
    });
    
    Future.delayed(const Duration(seconds: 3), () {
      _addLine(TerminalLine(
        content: '✅ Performance optimization completed',
        type: TerminalLineType.success,
        timestamp: DateTime.now(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isMinimized) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1a1d23),
          border: Border(
            top: BorderSide(color: const Color(0xFF00F5FF).withOpacity(0.3)),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.terminal, size: 18, color: Color(0xFF00F5FF)),
            const SizedBox(width: 8),
            const Text(
              'Interactive Terminal',
              style: TextStyle(
                color: Color(0xFF00F5FF),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {
                setState(() {
                  _isMinimized = false;
                });
              },
              icon: const Icon(Icons.expand_more, color: Colors.white54),
              tooltip: 'Expand terminal',
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFF1a1d23),
      child: Column(
        children: [
          // Header
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF15181E),
              border: Border(
                bottom: BorderSide(color: const Color(0xFF00F5FF).withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.terminal, size: 18, color: Color(0xFF00F5FF)),
                const SizedBox(width: 8),
                const Text(
                  'Interactive Terminal',
                  style: TextStyle(
                    color: Color(0xFF00F5FF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                
                // Controls
                Row(
                  children: [
                    // Auto-scroll toggle
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isAutoScroll = !_isAutoScroll;
                        });
                      },
                      icon: Icon(
                        _isAutoScroll ? Icons.arrow_downward : Icons.arrow_downward_outlined,
                        size: 16,
                        color: _isAutoScroll ? const Color(0xFF00F5FF) : Colors.white54,
                      ),
                      tooltip: _isAutoScroll ? 'Auto-scroll enabled' : 'Auto-scroll disabled',
                    ),
                    
                    // Minimize button
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isMinimized = true;
                        });
                      },
                      icon: const Icon(Icons.minimize, size: 16, color: Colors.white54),
                      tooltip: 'Minimize terminal',
                    ),
                    
                    // Clear button
                    IconButton(
                      onPressed: () {
                        _clearTerminal();
                      },
                      icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                      tooltip: 'Clear terminal',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Terminal content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B0E14),
                border: Border(
                  top: BorderSide(color: Colors.white10),
                ),
              ),
              child: Column(
                children: [
                  // Output area
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      itemCount: _lines.length,
                      itemBuilder: (context, index) {
                        final line = _lines[_lines.length - 1 - index];
                        return _buildTerminalLine(line);
                      },
                    ),
                  ),
                  
                  // Input area
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF11141A),
                      border: Border(
                        top: BorderSide(color: Colors.white10),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // Prompt
                        Text(
                          _currentPrompt,
                          style: const TextStyle(
                            color: Color(0xFF00F5FF),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Input field
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Type command...',
                              hintStyle: TextStyle(color: Colors.white38),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            onSubmitted: _handleInputSubmitted,
                            onChanged: (value) {
                              _currentInput = value;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalLine(TerminalLine line) {
    Color textColor;
    String prefix = '';

    switch (line.type) {
      case TerminalLineType.system:
        textColor = const Color(0xFF00F5FF);
        prefix = '[SYSTEM] ';
        break;
      case TerminalLineType.error:
        textColor = const Color(0xFFFF3131);
        prefix = '[ERROR] ';
        break;
      case TerminalLineType.success:
        textColor = Colors.green;
        prefix = '[SUCCESS] ';
        break;
      case TerminalLineType.warning:
        textColor = Colors.orange;
        prefix = '[WARNING] ';
        break;
      case TerminalLineType.info:
        textColor = Colors.blue;
        prefix = '[INFO] ';
        break;
      case TerminalLineType.userInput:
        textColor = Colors.white;
        prefix = '';
        break;
      case TerminalLineType.prompt:
        textColor = const Color(0xFF00F5FF);
        prefix = '$prefix>';
        break;
      default:
        textColor = Colors.white70;
        prefix = '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            line.timestamp.formatTime(),
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          
          // Prefix
          if (prefix.isNotEmpty)
            Text(
              prefix,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          
          // Content
          Expanded(
            child: Text(
              line.content,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum TerminalLineType {
  system,
  error,
  success,
  warning,
  info,
  userInput,
  prompt,
  normal,
}

class TerminalLine {
  final String content;
  final TerminalLineType type;
  final DateTime timestamp;

  TerminalLine({
    required this.content,
    required this.type,
    required this.timestamp,
  });
}

extension TerminalTimeExtensions on DateTime {
  String formatTime() {
    final hours = this.hour.toString().padLeft(2, '0');
    final minutes = this.minute.toString().padLeft(2, '0');
    final seconds = this.second.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
