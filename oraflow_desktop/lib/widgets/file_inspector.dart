import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github-gist.dart';
import '../services/scanner_service.dart';
import '../services/error_classifier.dart';

class FileInspector extends StatefulWidget {
  final String? filePath;
  final String? selectedCode;
  final int? selectedLine;
  final List<String> errorFiles;

  const FileInspector({
    Key? key,
    this.filePath,
    this.selectedCode,
    this.selectedLine,
    this.errorFiles = const [],
  }) : super(key: key);

  @override
  State<FileInspector> createState() => _FileInspectorState();
}

class _FileInspectorState extends State<FileInspector> {
  late TextEditingController _searchController;
  late ScrollController _scrollController;
  String _searchQuery = '';
  int _currentSearchIndex = 0;
  List<int> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.filePath == null && widget.selectedCode == null) {
      return _buildEmptyState();
    }

    return Container(
      color: const Color(0xFF1a1d23),
      child: Column(
        children: [
          // Header with file info and controls
          _buildHeader(),
          
          // Search bar
          _buildSearchBar(),
          
          // File content area
          Expanded(
            child: _buildFileContent(),
          ),
          
          // File analysis summary
          _buildFileSummary(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: const Color(0xFF1a1d23),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_drive_file,
              color: Colors.white24,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'File Inspector',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a file from the\nKnowledge Graph to view details',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final fileName = widget.filePath?.split('/').last ?? 'Unknown File';
    final isErroredFile = widget.errorFiles.contains(widget.filePath);

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
          // File icon
          Icon(
            isErroredFile ? Icons.error : Icons.insert_drive_file,
            color: isErroredFile ? const Color(0xFFFF3131) : const Color(0xFF00F5FF),
            size: 20,
          ),
          const SizedBox(width: 8),
          
          // File name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.filePath != null)
                  Text(
                    widget.filePath!,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          
          // Actions
          Row(
            children: [
              IconButton(
                onPressed: _copyFilePath,
                icon: const Icon(Icons.copy, size: 16),
                color: Colors.white54,
                tooltip: 'Copy file path',
              ),
              IconButton(
                onPressed: _openInVSCode,
                icon: const Icon(Icons.open_in_new, size: 16),
                color: const Color(0xFF00F5FF),
                tooltip: 'Open in VS Code',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF11141A),
        border: Border(
          bottom: BorderSide(color: Colors.white10),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search in file...',
                hintStyle: const TextStyle(color: Colors.white38),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_searchResults.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '${_currentSearchIndex + 1}/${_searchResults.length}',
                style: const TextStyle(
                  color: Color(0xFF00F5FF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileContent() {
    final content = widget.selectedCode ?? _loadFileContent();

    if (content == null) {
      return const Center(
        child: Text(
          'Unable to load file content',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Stack(
      children: [
        // Highlighted code
        HighlightView(
          content,
          language: 'dart',
          theme: githubGistTheme,
          padding: const EdgeInsets.all(16),
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.6,
          ),
          tabSize: 2,
        ),
        
        // Line highlighting for selected line
        if (widget.selectedLine != null)
          _buildLineHighlighter(content),
        
        // Search result highlights
        if (_searchResults.isNotEmpty)
          _buildSearchHighlights(content),
      ],
    );
  }

  Widget _buildLineHighlighter(String content) {
    final lines = content.split('\n');
    final targetLine = widget.selectedLine! - 1; // Convert to 0-based
    
    if (targetLine >= 0 && targetLine < lines.length) {
      final lineHeight = 18.0; // Approximate line height
      final topOffset = targetLine * lineHeight;

      return Positioned(
        left: 0,
        right: 0,
        top: topOffset,
        child: Container(
          height: lineHeight + 4,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF00F5FF).withOpacity(0.3),
                const Color(0xFF00F5FF).withOpacity(0.0),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSearchHighlights(String content) {
    // This would require custom implementation for search highlighting
    // For now, we'll show a simple overlay
    return const SizedBox.shrink();
  }

  Widget _buildFileSummary() {
    final content = widget.selectedCode ?? _loadFileContent();
    if (content == null) return const SizedBox.shrink();

    final analysis = content.analyze();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF11141A),
        border: Border(
          top: BorderSide(color: Colors.white10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'File Analysis',
            style: TextStyle(
              color: Color(0xFF00F5FF),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Metrics row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMetricChip('Lines', analysis.lineCount.toString()),
              _buildMetricChip('Functions', analysis.functionCount.toString()),
              _buildMetricChip('Classes', analysis.classCount.toString()),
              _buildMetricChip('Imports', analysis.importCount.toString()),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Code quality indicators
          if (analysis.hasIssues)
            _buildQualityIndicators(analysis),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2f3a),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF00F5FF),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityIndicators(FileAnalysisResult analysis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Code Quality',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (analysis.hasLongLines)
              _buildQualityBadge('Long lines', Colors.orange),
            if (analysis.hasDeepNesting)
              _buildQualityBadge('Deep nesting', Colors.yellow),
            if (analysis.hasManyParameters)
              _buildQualityBadge('Many parameters', Colors.pink),
            if (analysis.hasComplexLogic)
              _buildQualityBadge('Complex logic', Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _buildQualityBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
      
      if (_isSearching) {
        _searchResults = _findSearchResults(widget.selectedCode ?? _loadFileContent() ?? '', query);
        _currentSearchIndex = 0;
      } else {
        _searchResults.clear();
      }
    });
  }

  List<int> _findSearchResults(String content, String query) {
    final results = <int>[];
    final lines = content.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].toLowerCase().contains(query.toLowerCase())) {
        results.add(i);
      }
    }
    
    return results;
  }

  String? _loadFileContent() {
    if (widget.filePath == null) return null;
    
    try {
      return File(widget.filePath!).readAsStringSync();
    } catch (e) {
      print('Failed to load file: $e');
      return null;
    }
  }

  void _copyFilePath() {
    if (widget.filePath != null) {
      // In a real implementation, this would copy to clipboard
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied: ${widget.filePath}')),
      );
    }
  }

  void _openInVSCode() {
    if (widget.filePath != null) {
      // In a real implementation, this would open the file in VS Code
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening: ${widget.filePath}')),
      );
    }
  }
}

class FileAnalysisResult {
  final int lineCount;
  final int functionCount;
  final int classCount;
  final int importCount;
  final bool hasIssues;
  final bool hasLongLines;
  final bool hasDeepNesting;
  final bool hasManyParameters;
  final bool hasComplexLogic;

  FileAnalysisResult({
    required this.lineCount,
    required this.functionCount,
    required this.classCount,
    required this.importCount,
    required this.hasIssues,
    required this.hasLongLines,
    required this.hasDeepNesting,
    required this.hasManyParameters,
    required this.hasComplexLogic,
  });
}

extension FileInspectorExtensions on String {
  FileAnalysisResult analyze() {
    final lines = split('\n');
    int functionCount = 0;
    int classCount = 0;
    int importCount = 0;
    bool hasLongLines = false;
    bool hasDeepNesting = false;
    bool hasManyParameters = false;
    bool hasComplexLogic = false;

    for (final line in lines) {
      final trimmed = line.trim();
      
      if (trimmed.startsWith('import ')) {
        importCount++;
      } else if (trimmed.startsWith('class ')) {
        classCount++;
      } else if (trimmed.contains('()') && (trimmed.contains('=>') || trimmed.contains('{'))) {
        functionCount++;
      }

      // Quality checks
      if (line.length > 120) hasLongLines = true;
      if (line.startsWith('  ' * 6)) hasDeepNesting = true;
      if (trimmed.contains('(') && trimmed.split(',').length > 4) hasManyParameters = true;
      if (trimmed.contains('if') && trimmed.contains('&&') && trimmed.contains('||')) hasComplexLogic = true;
    }

    final hasIssues = hasLongLines || hasDeepNesting || hasManyParameters || hasComplexLogic;

    return FileAnalysisResult(
      lineCount: lines.length,
      functionCount: functionCount,
      classCount: classCount,
      importCount: importCount,
      hasIssues: hasIssues,
      hasLongLines: hasLongLines,
      hasDeepNesting: hasDeepNesting,
      hasManyParameters: hasManyParameters,
      hasComplexLogic: hasComplexLogic,
    );
  }
}
