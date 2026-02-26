import 'dart:async';
import 'package:flutter/material.dart';
import '../services/terminal_service.dart';
import '../services/resource_guard_service.dart';
import '../services/semantic_analyzer_service.dart';

class StatusBar extends StatefulWidget {
  final TerminalService terminalService;
  final ResourceGuardService resourceGuardService;
  final SemanticAnalyzerService semanticAnalyzerService;

  const StatusBar({
    Key? key,
    required this.terminalService,
    required this.resourceGuardService,
    required this.semanticAnalyzerService,
  }) : super(key: key);

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  late Timer _updateTimer;
  String _currentTime = '';
  int _errorCount = 0;
  int _fixCount = 0;
  double _cpuUsage = 0.0;
  double _memoryUsage = 0.0;
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    
    // Update time every second
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now().formatTime();
      });
    });

    // Listen to service updates
    widget.terminalService.errorStream.listen((error) {
      setState(() {
        _errorCount++;
      });
    });

    widget.resourceGuardService.resourceUsageStream.listen((usage) {
      setState(() {
        _cpuUsage = usage.cpuUsage;
        _memoryUsage = usage.memoryUsage;
      });
    });

    widget.semanticAnalyzerService.semanticErrorStream.listen((error) {
      setState(() {
        _errorCount++;
      });
    });
  }

  @override
  void dispose() {
    _updateTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _isMonitoring = widget.terminalService.isMonitoring;
    
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF11141A),
        border: Border(
          top: BorderSide(color: const Color(0xFF00F5FF).withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          // Left section: Status indicators
          Expanded(
            child: Row(
              children: [
                // Monitoring status
                _buildStatusIndicator(
                  icon: _isMonitoring ? Icons.circle : Icons.circle_outlined,
                  color: _isMonitoring ? Colors.green : Colors.red,
                  tooltip: _isMonitoring ? 'Monitoring Active' : 'Monitoring Inactive',
                ),
                
                // Error count
                _buildStatusIndicator(
                  icon: _errorCount > 0 ? Icons.error : Icons.check_circle,
                  color: _errorCount > 0 ? const Color(0xFFFF3131) : Colors.green,
                  tooltip: 'Errors: $_errorCount',
                  text: _errorCount > 0 ? '$_errorCount' : null,
                ),
                
                // Fix count
                _buildStatusIndicator(
                  icon: _fixCount > 0 ? Icons.build : Icons.build_outlined,
                  color: _fixCount > 0 ? const Color(0xFF00F5FF) : Colors.white54,
                  tooltip: 'Fixes Applied: $_fixCount',
                  text: _fixCount > 0 ? '$_fixCount' : null,
                ),
                
                // AI requests
                _buildStatusIndicator(
                  icon: Icons.psychology,
                  color: widget.resourceGuardService.concurrentAiRequests > 0 
                      ? const Color(0xFF667eea) 
                      : Colors.white54,
                  tooltip: 'AI Requests: ${widget.resourceGuardService.concurrentAiRequests}/2',
                  text: widget.resourceGuardService.concurrentAiRequests > 0 
                      ? '${widget.resourceGuardService.concurrentAiRequests}' 
                      : null,
                ),
              ],
            ),
          ),
          
          // Center section: Project info
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.terminalService.projectRoot != null)
                    Text(
                      '📁 ${widget.terminalService.projectRoot!.split('/').last}',
                      style: const TextStyle(
                        color: Color(0xFF00F5FF),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (widget.terminalService.projectRoot != null)
                    const SizedBox(width: 16),
                  Text(
                    '⏰ $_currentTime',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Right section: Resource usage
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // CPU Usage
                _buildResourceIndicator(
                  label: 'CPU',
                  value: _cpuUsage,
                  max: 100.0,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                
                // Memory Usage
                _buildResourceIndicator(
                  label: 'RAM',
                  value: _memoryUsage,
                  max: 100.0,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                
                // Semantic Analysis
                _buildStatusIndicator(
                  icon: widget.semanticAnalyzerService.isRecording 
                      ? Icons.fiber_manual_record 
                      : Icons.fiber_manual_record_outlined,
                  color: widget.semanticAnalyzerService.isRecording 
                      ? Colors.red 
                      : Colors.white54,
                  tooltip: 'Semantic Analysis: ${widget.semanticAnalyzerService.isRecording ? 'Recording' : 'Idle'}',
                  text: widget.semanticAnalyzerService.eventLog.length > 0 
                      ? '${widget.semanticAnalyzerService.eventLog.length}' 
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator({
    required IconData icon,
    required Color color,
    required String tooltip,
    String? text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white10),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          if (text != null) ...[
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(width: 4),
          Text(
            tooltip,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceIndicator({
    required String label,
    required double value,
    required double max,
    required Color color,
  }) {
    final percentage = max > 0 ? (value / max) * 100 : 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white10),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 60,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${percentage.toInt()}%',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

extension DateTimeExtensions on DateTime {
  String formatTime() {
    final hours = this.hour.toString().padLeft(2, '0');
    final minutes = this.minute.toString().padLeft(2, '0');
    final seconds = this.second.toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class ResourceUsage {
  final double cpuUsage;
  final double memoryUsage;

  ResourceUsage({required this.cpuUsage, required this.memoryUsage});
}
