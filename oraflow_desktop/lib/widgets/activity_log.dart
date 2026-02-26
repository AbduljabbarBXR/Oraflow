import 'dart:async';
import 'package:flutter/material.dart';
import '../services/terminal_service.dart';
import '../services/semantic_analyzer_service.dart';
import '../services/resource_guard_service.dart';

class ActivityLog extends StatefulWidget {
  final TerminalService terminalService;
  final ResourceGuardService resourceGuardService;
  final SemanticAnalyzerService semanticAnalyzerService;

  const ActivityLog({
    Key? key,
    required this.terminalService,
    required this.resourceGuardService,
    required this.semanticAnalyzerService,
  }) : super(key: key);

  @override
  State<ActivityLog> createState() => _ActivityLogState();
}

class _ActivityLogState extends State<ActivityLog> {
  final List<ActivityEntry> _activityEntries = [];
  late ScrollController _scrollController;
  bool _isAutoScroll = true;
  bool _isPaused = false;
  int _errorCount = 0;
  int _fixCount = 0;
  int _aiRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // Listen to all activity streams
    _setupListeners();
    
    // Add initial system startup entry
    _addEntry(ActivityEntry(
      type: ActivityType.system,
      message: 'OraFlow Activity Monitor started',
      timestamp: DateTime.now(),
      details: 'Dashboard initialized and monitoring services started',
    ));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setupListeners() {
    // Terminal service events
    widget.terminalService.errorStream.listen((error) {
      _addEntry(ActivityEntry(
        type: ActivityType.error,
        message: 'Error detected: ${error.errorMessage}',
        timestamp: DateTime.now(),
        details: 'File: ${error.filePath}, Line: ${error.line}',
      ));
      _errorCount++;
    });

    widget.terminalService.logStream.listen((log) {
      if (log.contains('BUILD SUCCESSFUL') || log.contains('Hot reload')) {
        _addEntry(ActivityEntry(
          type: ActivityType.success,
          message: 'Build completed successfully',
          timestamp: DateTime.now(),
          details: log,
        ));
      } else if (log.contains('ERROR') || log.contains('Exception')) {
        _addEntry(ActivityEntry(
          type: ActivityType.error,
          message: 'Terminal error detected',
          timestamp: DateTime.now(),
          details: log,
        ));
      }
    });

    // Resource guard events
    widget.resourceGuardService.resourceUsageStream.listen((usage) {
      if (usage.cpuUsage > 80 || usage.memoryUsage > 80) {
        _addEntry(ActivityEntry(
          type: ActivityType.warning,
          message: 'High resource usage detected',
          timestamp: DateTime.now(),
          details: 'CPU: ${usage.cpuUsage.toInt()}%, RAM: ${usage.memoryUsage.toInt()}%',
        ));
      }
    });

    widget.resourceGuardService.aiRequestStream.listen((request) {
      _addEntry(ActivityEntry(
        type: ActivityType.ai,
        message: 'AI request processed',
        timestamp: DateTime.now(),
        details: 'Request: ${request.requestType}, Status: ${request.status}',
      ));
      _aiRequestCount++;
    });

    // Semantic analysis events
    widget.semanticAnalyzerService.semanticErrorStream.listen((error) {
      _addEntry(ActivityEntry(
        type: ActivityType.semantic,
        message: 'Semantic issue detected: ${error.type}',
        timestamp: DateTime.now(),
        details: error.description,
      ));
    });

    widget.semanticAnalyzerService.eventLogStream.listen((events) {
      if (events.isNotEmpty) {
        _addEntry(ActivityEntry(
          type: ActivityType.analysis,
          message: 'Code analysis completed',
          timestamp: DateTime.now(),
          details: 'Found ${events.length} semantic events',
        ));
      }
    });
  }

  void _addEntry(ActivityEntry entry) {
    if (_isPaused) return;

    setState(() {
      _activityEntries.insert(0, entry);
      
      // Keep only last 100 entries to prevent memory issues
      if (_activityEntries.length > 100) {
        _activityEntries.removeRange(100, _activityEntries.length);
      }
    });

    // Auto-scroll to bottom if enabled
    if (_isAutoScroll) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1a1d23),
      child: Column(
        children: [
          // Header with controls
          _buildHeader(),
          
          // Activity entries
          Expanded(
            child: _buildActivityList(),
          ),
          
          // Summary footer
          _buildSummary(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF15181E),
        border: Border(
          bottom: BorderSide(color: const Color(0xFF00F5FF).withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          // Title
          const Icon(Icons.history, size: 18, color: Color(0xFF00F5FF)),
          const SizedBox(width: 8),
          const Text(
            'Activity Log',
            style: TextStyle(
              color: Color(0xFF00F5FF),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          
          // Controls
          Row(
            children: [
              // Pause/Resume button
              IconButton(
                onPressed: () {
                  setState(() {
                    _isPaused = !_isPaused;
                  });
                  _addEntry(ActivityEntry(
                    type: ActivityType.system,
                    message: _isPaused ? 'Activity log paused' : 'Activity log resumed',
                    timestamp: DateTime.now(),
                    details: 'Manual pause/resume action',
                  ));
                },
                icon: Icon(
                  _isPaused ? Icons.play_arrow : Icons.pause,
                  size: 16,
                  color: _isPaused ? Colors.green : Colors.white54,
                ),
                tooltip: _isPaused ? 'Resume' : 'Pause',
              ),
              
              // Clear button
              IconButton(
                onPressed: () {
                  setState(() {
                    _activityEntries.clear();
                  });
                  _addEntry(ActivityEntry(
                    type: ActivityType.system,
                    message: 'Activity log cleared',
                    timestamp: DateTime.now(),
                    details: 'Manual clear action',
                  ));
                },
                icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                tooltip: 'Clear log',
              ),
              
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    if (_activityEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              color: Colors.white24,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'No activity yet',
              style: TextStyle(color: Colors.white54),
            ),
            const Text(
              'Activity will appear here as events occur',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Show latest at top
      itemCount: _activityEntries.length,
      itemBuilder: (context, index) {
        final entry = _activityEntries[index];
        return _buildActivityEntry(entry);
      },
    );
  }

  Widget _buildActivityEntry(ActivityEntry entry) {
    final iconData = _getIconForType(entry.type);
    final color = _getColorForType(entry.type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white10),
        ),
        color: entry.type == ActivityType.error 
            ? const Color(0xFFFF3131).withOpacity(0.1)
            : Colors.transparent,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Icon(iconData, size: 16, color: color),
          const SizedBox(width: 12),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main message
                Text(
                  entry.message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: entry.type == ActivityType.error ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                
                // Details (optional)
                if (entry.details != null && entry.details!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      entry.details!,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ),
                
                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    entry.timestamp.formatTime(),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Text(
              entry.type.name.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF11141A),
        border: Border(
          top: BorderSide(color: Colors.white10),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSummaryChip('Errors', _errorCount, Colors.red),
          _buildSummaryChip('Fixes', _fixCount, const Color(0xFF00F5FF)),
          _buildSummaryChip('AI Requests', _aiRequestCount, const Color(0xFF667eea)),
          _buildSummaryChip('Total Events', _activityEntries.length, Colors.white54),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, int count, Color color) {
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  IconData _getIconForType(ActivityType type) {
    switch (type) {
      case ActivityType.error:
        return Icons.error;
      case ActivityType.success:
        return Icons.check_circle;
      case ActivityType.warning:
        return Icons.warning;
      case ActivityType.ai:
        return Icons.psychology;
      case ActivityType.semantic:
        return Icons.psychology_alt;
      case ActivityType.analysis:
        return Icons.analytics;
      case ActivityType.system:
        return Icons.settings;
    }
  }

  Color _getColorForType(ActivityType type) {
    switch (type) {
      case ActivityType.error:
        return const Color(0xFFFF3131);
      case ActivityType.success:
        return Colors.green;
      case ActivityType.warning:
        return Colors.orange;
      case ActivityType.ai:
        return const Color(0xFF667eea);
      case ActivityType.semantic:
        return Colors.purple;
      case ActivityType.analysis:
        return Colors.blue;
      case ActivityType.system:
        return Colors.white54;
    }
  }
}

enum ActivityType {
  error,
  success,
  warning,
  ai,
  semantic,
  analysis,
  system,
}

class ActivityEntry {
  final ActivityType type;
  final String message;
  final DateTime timestamp;
  final String? details;

  ActivityEntry({
    required this.type,
    required this.message,
    required this.timestamp,
    this.details,
  });
}

extension ActivityLogExtensions on DateTime {
  String formatTime() {
    final hours = this.hour.toString().padLeft(2, '0');
    final minutes = this.minute.toString().padLeft(2, '0');
    final seconds = this.second.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}
