import 'package:flutter/material.dart';
import '../services/error_classifier.dart';

class ErrorBadge extends StatelessWidget {
  final String errorMessage;
  final bool isBuildError;
  final double size;
  final bool showTooltip;
  final bool showText;

  const ErrorBadge({
    Key? key,
    required this.errorMessage,
    this.isBuildError = false,
    this.size = 16.0,
    this.showTooltip = true,
    this.showText = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final classification = ErrorClassifier.classifyError(errorMessage, isBuildError);
    
    return Tooltip(
      preferBelow: false,
      message: classification.userFriendlyMessage,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getBackgroundColor(classification.colorBadge),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getBorderColor(classification.colorBadge),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _getBackgroundColor(classification.colorBadge).withOpacity(0.3),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color Indicator Dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getDotColor(classification.colorBadge),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
            if (showText) ...[
              const SizedBox(width: 6),
              Text(
                _getBadgeText(classification.type),
                style: TextStyle(
                  color: _getTextColor(classification.colorBadge),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ENHANCED: Get Background Color based on Badge Type
  Color _getBackgroundColor(ColorBadge badge) {
    switch (badge) {
      case ColorBadge.red:
        return Colors.red.withOpacity(0.15);
      case ColorBadge.orange:
        return Colors.orange.withOpacity(0.15);
      case ColorBadge.yellow:
        return Colors.yellow.withOpacity(0.15);
      case ColorBadge.green:
        return Colors.green.withOpacity(0.15);
      case ColorBadge.gray:
        return Colors.grey.withOpacity(0.15);
    }
  }

  // ENHANCED: Get Border Color based on Badge Type
  Color _getBorderColor(ColorBadge badge) {
    switch (badge) {
      case ColorBadge.red:
        return Colors.red[400]!;
      case ColorBadge.orange:
        return Colors.orange[400]!;
      case ColorBadge.yellow:
        return Colors.yellow[400]!;
      case ColorBadge.green:
        return Colors.green[400]!;
      case ColorBadge.gray:
        return Colors.grey[400]!;
    }
  }

  // ENHANCED: Get Dot Color based on Badge Type
  Color _getDotColor(ColorBadge badge) {
    switch (badge) {
      case ColorBadge.red:
        return Colors.red[600]!;
      case ColorBadge.orange:
        return Colors.orange[600]!;
      case ColorBadge.yellow:
        return Colors.yellow[600]!;
      case ColorBadge.green:
        return Colors.green[600]!;
      case ColorBadge.gray:
        return Colors.grey[600]!;
    }
  }

  // ENHANCED: Get Text Color based on Badge Type
  Color _getTextColor(ColorBadge badge) {
    switch (badge) {
      case ColorBadge.red:
      case ColorBadge.orange:
      case ColorBadge.yellow:
        return Colors.white;
      case ColorBadge.green:
      case ColorBadge.gray:
        return Colors.black87;
    }
  }

  // ENHANCED: Get Badge Text based on Error Type
  String _getBadgeText(String errorType) {
    switch (errorType) {
      case 'compilation':
        return 'COMPILATION';
      case 'runtime':
        return 'RUNTIME';
      case 'lint':
        return 'LINT';
      case 'semantic':
        return 'SEMANTIC';
      default:
        return 'UNKNOWN';
    }
  }
}

// ENHANCED: Compact Error Badge for Dense UI Areas
class CompactErrorBadge extends StatelessWidget {
  final String errorMessage;
  final bool isBuildError;
  final double size;

  const CompactErrorBadge({
    Key? key,
    required this.errorMessage,
    this.isBuildError = false,
    this.size = 12.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final classification = ErrorClassifier.classifyError(errorMessage, isBuildError);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getBadgeColor(classification.colorBadge),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          _getBadgeIcon(classification.type),
          size: size * 0.6,
          color: Colors.white,
        ),
      ),
    );
  }

  // ENHANCED: Get Badge Color for Compact Badge
  Color _getBadgeColor(ColorBadge badge) {
    switch (badge) {
      case ColorBadge.red:
        return Colors.red[600]!;
      case ColorBadge.orange:
        return Colors.orange[600]!;
      case ColorBadge.yellow:
        return Colors.yellow[600]!;
      case ColorBadge.green:
        return Colors.green[600]!;
      case ColorBadge.gray:
        return Colors.grey[600]!;
    }
  }

  // ENHANCED: Get Badge Icon based on Error Type
  IconData _getBadgeIcon(String errorType) {
    switch (errorType) {
      case 'compilation':
        return Icons.error_outline;
      case 'runtime':
        return Icons.error;
      case 'lint':
        return Icons.warning_amber;
      case 'semantic':
        return Icons.psychology;
      default:
        return Icons.help_outline;
    }
  }
}

// ENHANCED: Severity Badge for Priority Indication
class SeverityBadge extends StatelessWidget {
  final String errorMessage;
  final bool isBuildError;
  final bool showIcon;

  const SeverityBadge({
    Key? key,
    required this.errorMessage,
    this.isBuildError = false,
    this.showIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final classification = ErrorClassifier.classifyError(errorMessage, isBuildError);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: _getSeverityGradient(classification.severity),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon)
            Icon(
              _getSeverityIcon(classification.severity),
              size: 10,
              color: Colors.white,
            ),
          const SizedBox(width: 4),
          Text(
            classification.severity.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ENHANCED: Get Severity Gradient
  LinearGradient _getSeverityGradient(String severity) {
    switch (severity) {
      case 'critical':
        return const LinearGradient(
          colors: [Colors.red, Colors.orange],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case 'medium':
        return const LinearGradient(
          colors: [Colors.yellow, Colors.orange],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case 'low':
        return const LinearGradient(
          colors: [Colors.green, Colors.blue],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      default:
        return const LinearGradient(
          colors: [Colors.grey, Colors.blueGrey],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
    }
  }

  // ENHANCED: Get Severity Icon
  IconData _getSeverityIcon(String severity) {
    switch (severity) {
      case 'critical':
        return Icons.priority_high;
      case 'medium':
        return Icons.warning;
      case 'low':
        return Icons.info;
      default:
        return Icons.help;
    }
  }
}

// ENHANCED: Combined Error Indicator Widget
class ErrorIndicator extends StatelessWidget {
  final String errorMessage;
  final bool isBuildError;
  final bool showType;
  final bool showSeverity;
  final bool showCompact;

  const ErrorIndicator({
    Key? key,
    required this.errorMessage,
    this.isBuildError = false,
    this.showType = true,
    this.showSeverity = true,
    this.showCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (showCompact) {
      return CompactErrorBadge(
        errorMessage: errorMessage,
        isBuildError: isBuildError,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showType)
          ErrorBadge(
            errorMessage: errorMessage,
            isBuildError: isBuildError,
            showText: true,
            size: 18,
          ),
        if (showType && showSeverity) const SizedBox(width: 8),
        if (showSeverity)
          SeverityBadge(
            errorMessage: errorMessage,
            isBuildError: isBuildError,
            showIcon: true,
          ),
      ],
    );
  }
}
