import 'dart:math';
import 'package:flutter/material.dart';
import '../services/scanner_service.dart';

class KnowledgeGraphView extends StatefulWidget {
  final ProjectMap projectMap;
  final List<String> errorFiles; // Files with active errors for bug pulsing

  const KnowledgeGraphView({
    super.key,
    required this.projectMap,
    this.errorFiles = const [],
  });

  @override
  State<KnowledgeGraphView> createState() => _KnowledgeGraphViewState();
}

class _KnowledgeGraphViewState extends State<KnowledgeGraphView>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0E14), // Deep Space background
      child: InteractiveViewer(
        minScale: 0.1,
        maxScale: 5.0,
        child: SizedBox(
          width: 2000,
          height: 2000,
          child: CustomPaint(
            painter: KnowledgeGraphPainter(
              projectMap: widget.projectMap,
              errorFiles: widget.errorFiles,
              pulseAnimation: _pulseAnimation,
            ),
          ),
        ),
      ),
    );
  }
}

class KnowledgeGraphPainter extends CustomPainter {
  final ProjectMap projectMap;
  final List<String> errorFiles;
  final Animation<double> pulseAnimation;

  // Layout constants
  static const double nodeRadius = 25.0;
  static const double edgeWidth = 2.0;

  // Colors
  static const Color nodeColor = Color(0xFF00F5FF); // Electric Cyan
  static const Color edgeColor = Color(0xFF7000FF); // Deep Violet
  static const Color errorColor = Color(0xFFFF3131); // Neon Red
  static const Color textColor = Colors.white;

  KnowledgeGraphPainter({
    required this.projectMap,
    required this.errorFiles,
    required this.pulseAnimation,
  }) : super(repaint: pulseAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate node positions using force-directed layout approximation
    final nodePositions = _calculateNodePositions(size);

    // Draw edges first (behind nodes)
    _drawEdges(canvas, nodePositions);

    // Draw nodes
    _drawNodes(canvas, nodePositions);

    // Draw labels
    _drawLabels(canvas, nodePositions);
  }

  Map<String, Offset> _calculateNodePositions(Size size) {
    final positions = <String, Offset>{};
    final center = Offset(size.width / 2, size.height / 2);

    if (projectMap.nodes.isEmpty) return positions;

    // Simple circular layout for demonstration
    // A full force-directed layout would be more complex
    final radius = min(size.width, size.height) * 0.3;
    final angleStep = 2 * pi / max(projectMap.nodes.length, 1);

    for (int i = 0; i < projectMap.nodes.length; i++) {
      final angle = i * angleStep;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      positions[projectMap.nodes[i]] = Offset(x, y);
    }

    return positions;
  }

  void _drawEdges(Canvas canvas, Map<String, Offset> positions) {
    final edgePaint = Paint()
      ..color = edgeColor
      ..strokeWidth = edgeWidth
      ..style = PaintingStyle.stroke;

    for (final edge in projectMap.edges) {
      final fromPos = positions[edge.from];
      final toPos = positions[edge.to];

      if (fromPos != null && toPos != null) {
        // Draw curved edge
        final path = Path();
        path.moveTo(fromPos.dx, fromPos.dy);
        path.quadraticBezierTo(
          (fromPos.dx + toPos.dx) / 2 + 50, // Control point offset
          (fromPos.dy + toPos.dy) / 2,
          toPos.dx,
          toPos.dy,
        );

        canvas.drawPath(path, edgePaint);

        // Draw arrowhead
        _drawArrowHead(canvas, fromPos, toPos);
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to) {
    const arrowSize = 8.0;
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

  void _drawNodes(Canvas canvas, Map<String, Offset> positions) {
    for (final entry in positions.entries) {
      final position = entry.value;
      final fileName = entry.key;
      final isErrorFile = errorFiles.contains(fileName);

      // Calculate pulse scale for error files
      final scale = isErrorFile ? pulseAnimation.value : 1.0;

      // Node paint with glow effect
      final nodePaint = Paint()
        ..color = isErrorFile ? errorColor : nodeColor
        ..style = PaintingStyle.fill;

      // Glow effect
      final glowPaint = Paint()
        ..color = (isErrorFile ? errorColor : nodeColor).withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..style = PaintingStyle.fill;

      final scaledRadius = nodeRadius * scale;

      // Draw glow
      canvas.drawCircle(position, scaledRadius + 5, glowPaint);

      // Draw node
      canvas.drawCircle(position, scaledRadius, nodePaint);

      // Border
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(position, scaledRadius, borderPaint);
    }
  }

  void _drawLabels(Canvas canvas, Map<String, Offset> positions) {
    const textStyle = TextStyle(
      color: textColor,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (final entry in positions.entries) {
      final position = entry.value;
      final fileName = entry.key;

      // Extract just the filename without path
      final simpleName = fileName.split('/').last.replaceAll('.dart', '');

      textPainter.text = TextSpan(text: simpleName, style: textStyle);
      textPainter.layout();

      // Position label below the node
      final labelOffset = Offset(
        position.dx - textPainter.width / 2,
        position.dy + nodeRadius + 8,
      );

      textPainter.paint(canvas, labelOffset);
    }
  }

  @override
  bool shouldRepaint(covariant KnowledgeGraphPainter oldDelegate) {
    return oldDelegate.projectMap != projectMap ||
           oldDelegate.errorFiles != errorFiles;
  }
}
