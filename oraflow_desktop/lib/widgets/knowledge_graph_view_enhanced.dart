import 'dart:math';
import 'package:flutter/material.dart';
import '../services/scanner_service.dart';
import '../widgets/error_badge.dart';
import '../services/error_classifier.dart';

class KnowledgeGraphView extends StatefulWidget {
  final ProjectMap projectMap;
  final List<String> errorFiles;
  final Map<String, List<Map<String, dynamic>>> lintMap;
  final void Function(String file, int line)? onOpenFile;

  const KnowledgeGraphView({
    super.key,
    required this.projectMap,
    this.errorFiles = const [],
    this.lintMap = const {},
    this.onOpenFile,
  });

  @override
  State<KnowledgeGraphView> createState() => _KnowledgeGraphViewState();
}

class _KnowledgeGraphViewState extends State<KnowledgeGraphView>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String? _selectedNode;
  late TransformationController _transformController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _transformController = TransformationController();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Graph visualization
        Expanded(
          flex: 3,
          child: Container(
            color: const Color(0xFF0B0E14),
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.1,
              maxScale: 5.0,
              child: SizedBox(
                width: 3000,
                height: 2000,
                child: CustomPaint(
                    painter: KnowledgeGraphPainter(
                      projectMap: widget.projectMap,
                      errorFiles: widget.errorFiles,
                      lintMap: widget.lintMap,
                      pulseAnimation: _pulseAnimation,
                      selectedNode: _selectedNode,
                      onNodeTap: (nodeName) {
                        setState(() {
                          _selectedNode = _selectedNode == nodeName ? null : nodeName;
                        });
                      },
                    ),
                ),
              ),
            ),
          ),
        ),

        // Details panel
        SizedBox(
          width: 350,
          child: Container(
            color: const Color(0xFF1a1d23),
              child: _selectedNode != null && widget.projectMap.fileAnalysis.containsKey(_selectedNode)
                ? _buildDetailsPanel(widget.projectMap.fileAnalysis[_selectedNode]!)
                : _buildEmptyPanel(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsPanel(FileAnalysis analysis) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File name
            Text(
              analysis.fileName,
              style: const TextStyle(
                color: Color(0xFF00F5FF),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // File type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getTypeColor(analysis.fileType).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getTypeColor(analysis.fileType)),
              ),
              child: Text(
                analysis.fileType.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  color: _getTypeColor(analysis.fileType),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'Purpose',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              analysis.description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),

            // Metrics
            _buildMetricRow('Lines of Code', analysis.lineCount.toString()),
            _buildMetricRow('Imports', analysis.imports.length.toString()),
            _buildMetricRow('Exports', analysis.exports.length.toString()),

            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),

            // Imports list
            if (analysis.imports.isNotEmpty) ...[
              Text(
                'Dependencies (${analysis.imports.length})',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...analysis.imports.map((imp) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${imp.split('/').last}',
                      style: const TextStyle(
                        color: Color(0xFF00F5FF),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
            ],

            // Exports list
            if (analysis.exports.isNotEmpty) ...[
              Text(
                'Exports (${analysis.exports.length})',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...analysis.exports.map((exp) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${exp.split('/').last}',
                      style: const TextStyle(
                        color: Color(0xFFFFB74D),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            const SizedBox(height: 16),

            // Lint issues for this file (if any)
            Builder(builder: (context) {
              final lintKey = analysis.filePath.split('/').last;
              final lintList = widget.lintMap[lintKey] ?? [];
              if (lintList.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Lint Issues (${lintList.length})',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...lintList.map((li) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () {
                            // Invoke callback to open file in host editor
                            final fileStr = li['file']?.toString() ?? '';
                            final lineNo = (li['line'] is int) ? li['line'] as int : int.tryParse(li['line']?.toString() ?? '') ?? 1;
                            if (fileStr.isNotEmpty && widget.onOpenFile != null) {
                              widget.onOpenFile!(fileStr, lineNo);
                            }
                          },
                          child: Text(
                            '${li['line']}: ${li['message']}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      )),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPanel() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.white24,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Click a node to\nview file details',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF00F5FF),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String fileType) {
    switch (fileType) {
      case 'screen':
        return Colors.blue;
      case 'widget':
      case 'stateful_widget':
      case 'stateless_widget':
        return Colors.cyan;
      case 'service':
        return Colors.orange;
      case 'model':
        return Colors.purple;
      case 'provider':
      case 'bloc':
        return Colors.green;
      case 'constants':
        return Colors.yellow;
      case 'utility':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }
}

class KnowledgeGraphPainter extends CustomPainter {
  final ProjectMap projectMap;
  final List<String> errorFiles;
  final Map<String, List<Map<String, dynamic>>> lintMap;
  final Animation<double> pulseAnimation;
  final String? selectedNode;
  final Function(String) onNodeTap;

  static const double nodeRadius = 30.0;
  static const double edgeWidth = 2.0;

  static const Color nodeColor = Color(0xFF00F5FF);
  static const Color edgeColor = Color(0xFF7000FF);
  static const Color errorColor = Color(0xFFFF3131);
  static const Color textColor = Colors.white;
  static const Color selectedColor = Color(0xFFFFD700);

  late Map<String, Offset> nodePositions;

  KnowledgeGraphPainter({
    required this.projectMap,
    required this.errorFiles,
    required this.lintMap,
    required this.pulseAnimation,
    required this.selectedNode,
    required this.onNodeTap,
  }) : super(repaint: pulseAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate positions using improved force-directed layout
    nodePositions = _calculateNodePositions(size);

    // Draw edges
    _drawEdges(canvas);

    // Draw nodes
    _drawNodes(canvas);

    // Draw labels
    _drawLabels(canvas);
  }

  Map<String, Offset> _calculateNodePositions(Size size) {
    if (projectMap.nodes.isEmpty) return {};

    final positions = <String, Offset>{};
    final center = Offset(size.width / 2, size.height / 2);

    // Improved spring-like layout
    const iterations = 50;
    const k = 100; // Spring constant
    const c = 0.1; // Damping
    const repulsion = 1000;

    // Initialize positions randomly
    final random = Random(42); // Seed for reproducibility
    final velocity = <String, Offset>{};

    for (final node in projectMap.nodes) {
      final angle = random.nextDouble() * 2 * pi;
      final radius = 200 + random.nextDouble() * 300;
      positions[node] = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      velocity[node] = Offset.zero;
    }

    // Simulate spring forces
    for (int iter = 0; iter < iterations; iter++) {
      final forces = <String, Offset>{};

      // Initialize forces to zero
      for (final node in projectMap.nodes) {
        forces[node] = Offset.zero;
      }

      // Apply edge spring forces
      for (final edge in projectMap.edges) {
        final fromPos = positions[edge.from]!;
        final toPos = positions[edge.to]!;
        final delta = Offset(toPos.dx - fromPos.dx, toPos.dy - fromPos.dy);
        final distance = sqrt(delta.dx * delta.dx + delta.dy * delta.dy);

        if (distance > 0) {
          final force = (distance - k) / distance;
          final fx = force * delta.dx;
          final fy = force * delta.dy;

          forces[edge.from] = forces[edge.from]! + Offset(fx, fy);
          forces[edge.to] = forces[edge.to]! + Offset(-fx, -fy);
        }
      }

      // Apply repulsion forces
      for (int i = 0; i < projectMap.nodes.length; i++) {
        for (int j = i + 1; j < projectMap.nodes.length; j++) {
          final node1 = projectMap.nodes[i];
          final node2 = projectMap.nodes[j];
          final pos1 = positions[node1]!;
          final pos2 = positions[node2]!;
          final delta = Offset(pos2.dx - pos1.dx, pos2.dy - pos1.dy);
          final distance = max(sqrt(delta.dx * delta.dx + delta.dy * delta.dy), 1.0);

          final force = repulsion / (distance * distance);
          final fx = force * delta.dx / distance;
          final fy = force * delta.dy / distance;

          forces[node1] = forces[node1]! - Offset(fx, fy);
          forces[node2] = forces[node2]! + Offset(fx, fy);
        }
      }

      // Apply center force
      for (final node in projectMap.nodes) {
        final pos = positions[node]!;
        final delta = Offset(center.dx - pos.dx, center.dy - pos.dy);
        forces[node] = forces[node]! + delta * 0.01;
      }

      // Update velocities and positions
      for (final node in projectMap.nodes) {
        velocity[node] = (velocity[node]! + forces[node]!) * (1 - c);
        positions[node] = positions[node]! + velocity[node]!;

        // Keep within bounds
        final pos = positions[node]!;
        positions[node] = Offset(
          pos.dx.clamp(nodeRadius, size.width - nodeRadius),
          pos.dy.clamp(nodeRadius, size.height - nodeRadius),
        );
      }
    }

    return positions;
  }

  void _drawEdges(Canvas canvas) {
    final edgePaint = Paint()
      ..color = edgeColor
      ..strokeWidth = edgeWidth
      ..style = PaintingStyle.stroke;

    for (final edge in projectMap.edges) {
      final fromPos = nodePositions[edge.from];
      final toPos = nodePositions[edge.to];

      if (fromPos != null && toPos != null) {
        canvas.drawLine(fromPos, toPos, edgePaint);

        // Draw arrowhead
        _drawArrowHead(canvas, fromPos, toPos);
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to) {
    const arrowSize = 10.0;
    final angle = atan2(to.dy - from.dy, to.dx - from.dx);

    final arrowPaint = Paint()
      ..color = edgeColor
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(to.dx, to.dy);
    path.lineTo(
      to.dx - arrowSize * cos(angle - pi / 6),
      to.dy - arrowSize * sin(angle - pi / 6),
    );
    path.lineTo(
      to.dx - arrowSize * cos(angle + pi / 6),
      to.dy - arrowSize * sin(angle + pi / 6),
    );
    path.close();

    canvas.drawPath(path, arrowPaint);
  }

  void _drawNodes(Canvas canvas) {
    for (final entry in nodePositions.entries) {
      final fileName = entry.key;
      final position = entry.value;
      final isErrorFile = errorFiles.contains(fileName);
      final isSelected = selectedNode == fileName;

      // Calculate pulse scale
      final scale = isErrorFile ? pulseAnimation.value : 1.0;
      final scaledRadius = nodeRadius * scale;

      // Node color
      Color nodeCol = nodeColor;
      if (isErrorFile) nodeCol = errorColor;
      if (isSelected) nodeCol = selectedColor;

      // Glow effect
      final glowPaint = Paint()
        ..color = nodeCol.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(position, scaledRadius + 8, glowPaint);

      // Main node
      final nodePaint = Paint()
        ..color = nodeCol
        ..style = PaintingStyle.fill;

      canvas.drawCircle(position, scaledRadius, nodePaint);

      // Border
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3 : 1.5;

      canvas.drawCircle(position, scaledRadius, borderPaint);

      // Draw lint badge if present
      try {
        final base = fileName.split('/').last;
        final lintList = lintMap[base] ?? [];
        if (lintList.isNotEmpty) {
          final badgeRadius = 8.0;
          final badgeOffset = Offset(position.dx + scaledRadius - badgeRadius, position.dy - scaledRadius + badgeRadius);
          final badgePaint = Paint()..color = Colors.redAccent;
          canvas.drawCircle(badgeOffset, badgeRadius, badgePaint);

          // count text
          final tp = TextPainter(text: TextSpan(text: '${lintList.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr);
          tp.layout();
          tp.paint(canvas, badgeOffset - Offset(tp.width / 2, tp.height / 2));
        }
      } catch (e) {
        // ignore badge render errors
      }
    }
  }

  void _drawLabels(Canvas canvas) {
    const textStyle = TextStyle(
      color: textColor,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (final entry in nodePositions.entries) {
      final fileName = entry.key;
      final position = entry.value;

      // Extract just the filename
      final simpleName = fileName.split('/').last.replaceAll('.dart', '');

      textPainter.text = TextSpan(text: simpleName, style: textStyle);
      textPainter.layout();

      final labelOffset = Offset(
        position.dx - textPainter.width / 2,
        position.dy + nodeRadius + 10,
      );

      textPainter.paint(canvas, labelOffset);
    }
  }

  @override
  bool shouldRepaint(KnowledgeGraphPainter oldDelegate) => true;
}
