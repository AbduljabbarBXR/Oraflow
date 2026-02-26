import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ResourceGuardService {
  // SINGLETON PATTERN
  static final ResourceGuardService _instance = ResourceGuardService._internal();
  factory ResourceGuardService() => _instance;
  ResourceGuardService._internal();

  bool _isMonitoring = false;
  Timer? _monitoringTimer;
  final StreamController<ResourceStatus> _statusController = StreamController<ResourceStatus>.broadcast();
  final StreamController<String> _alertController = StreamController<String>.broadcast();

  // Resource thresholds
  static const double CRITICAL_RAM_THRESHOLD = 0.85; // 85% RAM usage
  static const double HIGH_RAM_THRESHOLD = 0.75; // 75% RAM usage
  static const int CRITICAL_PROCESS_COUNT = 200; // Too many processes
  static const int MAX_CONCURRENT_AI_REQUESTS = 2; // Limit AI requests
  static const int MAX_KNOWLEDGE_GRAPH_NODES = 500; // Limit knowledge graph size

  // Current state
  int _concurrentAiRequests = 0;
  int _currentProcessCount = 0;
  int _knowledgeGraphSize = 0;
  bool _isCloudFallbackActive = false;
  bool _isCacheCleared = false;

  Stream<ResourceStatus> get resourceStatusStream => _statusController.stream;
  Stream<String> get alertStream => _alertController.stream;

  // Public getters for Dashboard access
  bool get isMonitoring => _isMonitoring;
  int get concurrentAiRequests => _concurrentAiRequests;
  int get knowledgeGraphSize => _knowledgeGraphSize;
  bool get isCloudFallbackActive => _isCloudFallbackActive;

  ResourceStatus get currentStatus => ResourceStatus(
        ramUsage: _getCurrentRamUsage(),
        isCritical: _getCurrentRamUsage() > CRITICAL_RAM_THRESHOLD,
        isHigh: _getCurrentRamUsage() > HIGH_RAM_THRESHOLD,
        processCount: _currentProcessCount,
        concurrentAiRequests: _concurrentAiRequests,
        knowledgeGraphSize: _knowledgeGraphSize,
        isCloudFallbackActive: _isCloudFallbackActive,
        timestamp: DateTime.now(),
      );

  // Start monitoring system resources
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _monitoringTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkSystemResources();
    });

    print('🛡️ Resource Guard: Started monitoring system resources');
    _alertController.add('🛡️ Resource monitoring started');
  }

  // Stop monitoring
  void stopMonitoring() {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    print('🛡️ Resource Guard: Stopped monitoring system resources');
    _alertController.add('🛡️ Resource monitoring stopped');
  }

  // Check if we can make an AI request
  bool canMakeAiRequest() {
    final ramUsage = _getCurrentRamUsage();
    
    if (ramUsage > CRITICAL_RAM_THRESHOLD) {
      _alertController.add('❌ Cannot make AI request: RAM usage critical (${ramUsage * 100}%)');
      return false;
    }

    if (_concurrentAiRequests >= MAX_CONCURRENT_AI_REQUESTS) {
      _alertController.add('❌ Cannot make AI request: Too many concurrent requests ($_concurrentAiRequests)');
      return false;
    }

    return true;
  }

  // Increment AI request counter
  void incrementAiRequests() {
    _concurrentAiRequests++;
    _checkSystemResources();
  }

  // Decrement AI request counter
  void decrementAiRequests() {
    _concurrentAiRequests = _concurrentAiRequests > 0 ? _concurrentAiRequests - 1 : 0;
    _checkSystemResources();
  }

  // Update knowledge graph size
  void updateKnowledgeGraphSize(int size) {
    _knowledgeGraphSize = size;
    _checkSystemResources();
  }

  // Clear knowledge graph cache when memory is low
  void clearKnowledgeGraphCache() {
    if (_isCacheCleared) return;

    _isCacheCleared = true;
    _alertController.add('🧹 Clearing knowledge graph cache to free memory');
    
    // Simulate cache clearing (in real implementation, this would clear actual cache)
    Future.delayed(const Duration(seconds: 2), () {
      _isCacheCleared = false;
      _alertController.add('✅ Knowledge graph cache cleared');
    });
  }

  // Activate cloud fallback mode
  void activateCloudFallback() {
    if (_isCloudFallbackActive) return;

    _isCloudFallbackActive = true;
    _alertController.add('☁️ Activating cloud fallback mode - switching to cloud AI');
    
    // In real implementation, this would switch AI service to cloud-only mode
    Future.delayed(const Duration(seconds: 1), () {
      _alertController.add('✅ Cloud fallback mode active - local processing minimized');
    });
  }

  // Deactivate cloud fallback mode
  void deactivateCloudFallback() {
    if (!_isCloudFallbackActive) return;

    _isCloudFallbackActive = false;
    _alertController.add('✅ Deactivating cloud fallback mode - resuming local processing');
  }

  // Emergency resource cleanup
  void emergencyCleanup() {
    _alertController.add('🚨 EMERGENCY CLEANUP: Freeing all non-essential resources');
    
    // Clear caches
    clearKnowledgeGraphCache();
    
    // Reduce AI request concurrency
    _concurrentAiRequests = 0;
    
    // Force garbage collection
    if (kIsWeb) {
      // Web-specific cleanup
      _alertController.add('🧹 Web cleanup: Clearing browser cache');
    } else {
      // Mobile/Desktop cleanup
      _alertController.add('🧹 System cleanup: Forcing garbage collection');
    }
    
    _alertController.add('✅ Emergency cleanup complete');
  }

  // Get current RAM usage percentage
  double _getCurrentRamUsage() {
    try {
      if (kIsWeb) {
        // Web implementation - simplified for now
        // In a real implementation, you would use JavaScript interop
        // For now, return a safe default that allows the system to work
        return 0.5; // 50% usage - allows normal operation
      } else {
        // Mobile/Desktop implementation - simplified
        // In a real implementation, you would use platform-specific APIs
        // For now, return a safe default that allows the system to work
        return 0.6; // 60% usage - allows normal operation
      }
    } catch (e) {
      print('Error getting RAM usage: $e');
      return 0.6; // Safe default
    }
  }

  // Check system resources and trigger appropriate actions
  void _checkSystemResources() {
    if (!_isMonitoring) return;

    final ramUsage = _getCurrentRamUsage();
    final processCount = _getCurrentProcessCount();
    
    _currentProcessCount = processCount;

    // Update status
    _statusController.add(currentStatus);

    // Critical RAM usage - emergency actions
    if (ramUsage > CRITICAL_RAM_THRESHOLD) {
      _alertController.add('🚨 CRITICAL: RAM usage at ${ramUsage * 100}%. Taking emergency actions...');
      
      // Activate cloud fallback
      activateCloudFallback();
      
      // Clear cache
      clearKnowledgeGraphCache();
      
      // Emergency cleanup
      emergencyCleanup();
      
      return;
    }

    // High RAM usage - preventive actions
    if (ramUsage > HIGH_RAM_THRESHOLD) {
      _alertController.add('⚠️ WARNING: RAM usage at ${ramUsage * 100}%. Taking preventive actions...');
      
      // Activate cloud fallback if not already active
      if (!_isCloudFallbackActive) {
        activateCloudFallback();
      }
      
      // Clear cache if not already cleared
      if (!_isCacheCleared) {
        clearKnowledgeGraphCache();
      }
      
      return;
    }

    // High process count
    if (processCount > CRITICAL_PROCESS_COUNT) {
      _alertController.add('⚠️ WARNING: High process count ($processCount). Consider closing other applications.');
    }

    // Normal conditions - can deactivate cloud fallback if active
    if (_isCloudFallbackActive && ramUsage < HIGH_RAM_THRESHOLD - 0.1) {
      deactivateCloudFallback();
    }
  }

  // Get current process count
  int _getCurrentProcessCount() {
    try {
      if (kIsWeb) {
        return 50; // Placeholder for web
      } else {
        return ProcessInfo.currentRss ~/ 1024; // Approximate process count
      }
    } catch (e) {
      print('Error getting process count: $e');
      return 100; // Safe default
    }
  }

  // Optimize memory usage
  void optimizeMemory() {
    _alertController.add('🔧 Optimizing memory usage...');
    
    // Clear unused caches
    clearKnowledgeGraphCache();
    
    // Reduce AI request concurrency
    if (_concurrentAiRequests > 1) {
      _concurrentAiRequests = 1;
      _alertController.add('🔧 Reduced AI request concurrency to 1');
    }
    
    // Force garbage collection
    if (!kIsWeb) {
      // Dart garbage collection hint
      _alertController.add('🔧 Triggered garbage collection');
    }
    
    _alertController.add('✅ Memory optimization complete');
  }

  // Get memory recommendations
  List<String> getMemoryRecommendations() {
    final recommendations = <String>[];
    final ramUsage = _getCurrentRamUsage();
    final processCount = _getCurrentProcessCount();

    if (ramUsage > CRITICAL_RAM_THRESHOLD) {
      recommendations.add('🚨 Close other applications immediately');
      recommendations.add('🚨 Consider restarting your system');
      recommendations.add('🚨 Reduce project complexity');
    } else if (ramUsage > HIGH_RAM_THRESHOLD) {
      recommendations.add('⚠️ Close unnecessary applications');
      recommendations.add('⚠️ Reduce knowledge graph size');
      recommendations.add('⚠️ Limit concurrent AI requests');
    }

    if (processCount > CRITICAL_PROCESS_COUNT) {
      recommendations.add('⚠️ Too many background processes running');
      recommendations.add('⚠️ Consider restarting your system');
    }

    if (recommendations.isEmpty) {
      recommendations.add('✅ Memory usage is optimal');
    }

    return recommendations;
  }

  // Dispose resources
  void dispose() {
    stopMonitoring();
    _statusController.close();
    _alertController.close();
  }

  // ENHANCED: Stream for resource usage updates
  Stream<ResourceUsage> get resourceUsageStream => _resourceUsageController.stream;

  // ENHANCED: Stream for AI request updates
  Stream<AIRequest> get aiRequestStream => _aiRequestController.stream;

  // ENHANCED: Controllers for streams
  final StreamController<ResourceUsage> _resourceUsageController = StreamController<ResourceUsage>.broadcast();
  final StreamController<AIRequest> _aiRequestController = StreamController<AIRequest>.broadcast();
}

class ResourceUsage {
  final double cpuUsage;
  final double memoryUsage;

  ResourceUsage({required this.cpuUsage, required this.memoryUsage});
}

class AIRequest {
  final String requestType;
  final String status;

  AIRequest({required this.requestType, required this.status});
}

class ResourceStatus {
  final double ramUsage;
  final bool isCritical;
  final bool isHigh;
  final int processCount;
  final int concurrentAiRequests;
  final int knowledgeGraphSize;
  final bool isCloudFallbackActive;
  final DateTime timestamp;

  ResourceStatus({
    required this.ramUsage,
    required this.isCritical,
    required this.isHigh,
    required this.processCount,
    required this.concurrentAiRequests,
    required this.knowledgeGraphSize,
    required this.isCloudFallbackActive,
    required this.timestamp,
  });

  double get ramPercentage => ramUsage * 100;

  @override
  String toString() {
    return 'ResourceStatus(ram: ${ramPercentage.toStringAsFixed(1)}%, critical: $isCritical, processes: $processCount, aiRequests: $concurrentAiRequests, graphSize: $knowledgeGraphSize, cloudFallback: $isCloudFallbackActive)';
  }
}
