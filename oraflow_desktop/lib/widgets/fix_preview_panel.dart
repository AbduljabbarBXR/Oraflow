import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:path/path.dart' as path;

class FixPreviewPanel extends StatefulWidget {
  final List<Map<String, dynamic>> edits;
  final ValueChanged<List<Map<String, dynamic>>> onAcceptSelected;
  final VoidCallback onReject;

  const FixPreviewPanel({
    Key? key,
    required this.edits,
    required this.onAcceptSelected,
    required this.onReject,
  }) : super(key: key);

  @override
  State<FixPreviewPanel> createState() => _FixPreviewPanelState();
}

class _FixPreviewPanelState extends State<FixPreviewPanel> {
  late List<bool> _selected;
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selected = List<bool>.filled(widget.edits.length, true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[900],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.code, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'OraFlow Fix Preview - ${widget.edits.length} edit(s)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: widget.onReject,
                  tooltip: 'Close preview',
                ),
              ],
            ),
          ),

          // Content Area: left = edit list, right = code diff for focused edit
          Container(
            height: 360,
            child: Row(
              children: [
                // Edit list with checkboxes
                SizedBox(
                  width: 300,
                  child: ListView.builder(
                    itemCount: widget.edits.length,
                    itemBuilder: (ctx, idx) {
                      final e = widget.edits[idx];
                      final file = e['file']?.toString() ?? 'unknown';
                      final line = e['startLine'] ?? e['line'] ?? 1;
                      final summary = e['newText'] ?? e['new_line_content'] ?? '';
                      return CheckboxListTile(
                        value: _selected[idx],
                        onChanged: (v) {
                          setState(() {
                            _selected[idx] = v ?? false;
                            _focusedIndex = idx;
                          });
                        },
                        title: Text('$file:${line.toString()}', style: const TextStyle(fontSize: 12)),
                        subtitle: Text(
                          summary.toString().trim().replaceAll('\n', ' '),
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
                ),

                // Focused diff preview
                Expanded(
                  child: _buildFocusedDiff(widget.edits[_focusedIndex] ?? {}),
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select edits to apply',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            final selectedEdits = <Map<String, dynamic>>[];
                            for (int i = 0; i < widget.edits.length; i++) {
                              if (_selected[i]) selectedEdits.add(widget.edits[i]);
                            }
                            widget.onAcceptSelected(selectedEdits);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Apply Selected'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: widget.onReject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red[600],
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusedDiff(Map<String, dynamic> edit) {
    final before = edit['old_line_content']?.toString() ?? edit['oldText']?.toString() ?? '/* before */';
    final after = edit['new_line_content']?.toString() ?? edit['newText']?.toString() ?? '/* after */';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(child: _buildCodeSection('BEFORE', before, Colors.red[50]!)),
          Expanded(child: _buildCodeSection('AFTER', after, Colors.green[50]!)),
        ],
      ),
    );
  }

  Widget _buildCodeSection(String title, String code, Color backgroundColor) {
    return Container(
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Bar
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
                fontSize: 12,
              ),
            ),
          ),
          
          // Code Content
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.all(16),
                child: HighlightView(
                  code,
                  language: 'dart',
                  theme: githubTheme,
                  padding: EdgeInsets.all(0),
                  textStyle: TextStyle(
                    fontFamily: 'Monaco, Consolas, "Courier New", monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper function to create a diff preview
class FixPreviewHelper {
  static String generateBeforeCode(String fullFile, int lineNumber, int contextLines) {
    final lines = fullFile.split('\n');
    final startLine = lineNumber - contextLines - 1; // -1 for 0-based indexing
    final endLine = lineNumber + contextLines;
    
    final result = <String>[];
    for (int i = startLine; i < endLine; i++) {
      if (i >= 0 && i < lines.length) {
        result.add(lines[i]);
      }
    }
    
    return result.join('\n');
  }

  static String generateAfterCode(String fullFile, int lineNumber, String replacement) {
    final lines = fullFile.split('\n');
    final lineIndex = lineNumber - 1; // Convert to 0-based
    
    if (lineIndex >= 0 && lineIndex < lines.length) {
      lines[lineIndex] = replacement;
    }
    
    return lines.join('\n');
  }
}
