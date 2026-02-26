import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

class HealthMonitor extends StatefulWidget {
  const HealthMonitor({super.key});

  @override
  State<HealthMonitor> createState() => _HealthMonitorState();
}

class _HealthMonitorState extends State<HealthMonitor> {
  double _cpuUsage = 0.0;
  double _ramUsage = 0.0;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateHealthMetrics();
    });
    _updateHealthMetrics(); // Initial update
  }

  Future<void> _updateHealthMetrics() async {
    try {
      // CPU Usage (Windows)
      final cpuUsage = await _getCpuUsage();
      final ramUsage = await _getRamUsage();

      if (mounted) {
        setState(() {
          _cpuUsage = cpuUsage;
          _ramUsage = ramUsage;
        });
      }
    } catch (e) {
      print('Health monitoring error: $e');
    }
  }

  Future<double> _getCpuUsage() async {
    try {
      // Windows: Use typeperf for CPU monitoring
      final result = await Process.run('typeperf', [
        '\\Processor(_Total)\\% Processor Time',
        '-sc',
        '1'
      ]);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        // Parse the CSV output
        final lines = output.split('\n');
        if (lines.length >= 3) {
          final lastLine = lines[lines.length - 2]; // Second to last line has data
          final parts = lastLine.split(',');
          if (parts.length >= 2) {
            final cpuValue = double.tryParse(parts[1].trim().replaceAll('"', ''));
            if (cpuValue != null && cpuValue >= 0 && cpuValue <= 100) {
              return cpuValue;
            }
          }
        }
      }
    } catch (e) {
      print('CPU monitoring failed: $e');
    }

    return 0.0; // Fallback
  }

  Future<double> _getRamUsage() async {
    try {
      // Windows: Use wmic for RAM info
      final result = await Process.run('wmic', [
        'OS',
        'get',
        'FreePhysicalMemory,TotalVisibleMemorySize',
        '/VALUE'
      ]);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final freeMatch = RegExp(r'FreePhysicalMemory=(\d+)').firstMatch(output);
        final totalMatch = RegExp(r'TotalVisibleMemorySize=(\d+)').firstMatch(output);

        if (freeMatch != null && totalMatch != null) {
          final freeMemory = int.parse(freeMatch.group(1)!);
          final totalMemory = int.parse(totalMatch.group(1)!);

          if (totalMemory > 0) {
            final usedMemory = totalMemory - freeMemory;
            final usagePercent = (usedMemory / totalMemory) * 100;
            return usagePercent.clamp(0.0, 100.0);
          }
        }
      }
    } catch (e) {
      print('RAM monitoring failed: $e');
    }

    return 0.0; // Fallback
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1d23),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'System Health',
            style: TextStyle(
              color: Color(0xFF00F5FF),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // CPU Usage
          _buildMetricBar(
            label: 'CPU',
            value: _cpuUsage,
            color: _getCpuColor(_cpuUsage),
          ),

          const SizedBox(height: 6),

          // RAM Usage
          _buildMetricBar(
            label: 'RAM',
            value: _ramUsage,
            color: _getRamColor(_ramUsage),
          ),

          const SizedBox(height: 4),

          // Usage text
          Text(
            'CPU: ${_cpuUsage.toStringAsFixed(1)}% | RAM: ${_ramUsage.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBar({
    required String label,
    required double value,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 30,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 100,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            '${value.toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Color _getCpuColor(double usage) {
    if (usage >= 90) return Colors.red;
    if (usage >= 70) return Colors.orange;
    if (usage >= 50) return Colors.yellow;
    return Colors.green;
  }

  Color _getRamColor(double usage) {
    if (usage >= 90) return Colors.red;
    if (usage >= 80) return Colors.orange;
    if (usage >= 60) return Colors.yellow;
    return Colors.green;
  }
}
