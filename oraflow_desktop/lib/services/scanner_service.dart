import 'dart:io';
import 'dart:async';
import 'lint_service.dart';

class FileAnalysis {
  final String filePath;
  final String fileName;
  final String fileType; // screen, service, widget, model, etc.
  final String description; // AI-generated or rule-based description
  final int lineCount;
  final List<String> imports;
  final List<String> exports;

  FileAnalysis({
    required this.filePath,
    required this.fileName,
    required this.fileType,
    required this.description,
    required this.lineCount,
    required this.imports,
    required this.exports,
  });

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'fileName': fileName,
        'fileType': fileType,
        'description': description,
        'lineCount': lineCount,
        'imports': imports,
        'exports': exports,
      };
}

class ProjectMap {
  final List<String> nodes; // File paths
  final List<ImportEdge> edges; // Import relationships
  final Map<String, FileAnalysis> fileAnalysis; // File metadata and descriptions

  ProjectMap({
    required this.nodes,
    required this.edges,
    this.fileAnalysis = const {},
  });

  Map<String, dynamic> toJson() => {
        'nodes': nodes,
        'edges': edges.map((e) => e.toJson()).toList(),
        'fileAnalysis': fileAnalysis.map((k, v) => MapEntry(k, v.toJson())),
      };
}

class ImportEdge {
  final String from; // Importing file
  final String to; // Imported file

  ImportEdge({
    required this.from,
    required this.to,
  });

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
      };
}

class ScannerService {
  final StreamController<ProjectMap> _projectMapController = StreamController<ProjectMap>.broadcast();
  final StreamController<List<dynamic>> _lintController = StreamController<List<dynamic>>.broadcast();

  Stream<List<dynamic>> get lintStream => _lintController.stream;

  Stream<ProjectMap> get projectMapStream => _projectMapController.stream;

  Future<ProjectMap> scanProject(String projectRoot) async {
    print('🔍 Starting Knowledge Graph scan of: $projectRoot');

    final libDir = Directory('$projectRoot/lib');
    if (!libDir.existsSync()) {
      throw Exception('Lib directory not found at: $projectRoot/lib');
    }

    final nodes = <String>[];
    final edges = <ImportEdge>[];
    final fileAnalysis = <String, FileAnalysis>{};

    // Recursive scan for all .dart files
    await _scanDirectory(libDir, projectRoot, nodes, edges, fileAnalysis);

    final projectMap = ProjectMap(
      nodes: nodes,
      edges: edges,
      fileAnalysis: fileAnalysis,
    );

    print('📊 Knowledge Graph complete: ${nodes.length} files, ${edges.length} imports');

    // Emit to stream for UI updates
    _projectMapController.add(projectMap);

    // Run lint analysis asynchronously and emit results
    try {
      final lintSvc = LintService();
      LintService().runDartAnalyze(projectRoot).then((issues) {
        final list = issues.map((i) => {'file': i.file, 'line': i.line, 'message': i.message}).toList();
        _lintController.add(list);
      });
    } catch (e) {
      // ignore lint errors
    }

    return projectMap;
  }

  Future<void> _scanDirectory(
    Directory dir,
    String projectRoot,
    List<String> nodes,
    List<ImportEdge> edges,
    Map<String, FileAnalysis> fileAnalysis,
  ) async {
    final List<FileSystemEntity> entities = dir.listSync(recursive: true);

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final relativePath = _getRelativePath(entity.path, projectRoot);
        nodes.add(relativePath);

        // Analyze the file
        final analysis = await _analyzeFile(entity, projectRoot, relativePath);
        fileAnalysis[relativePath] = analysis;

        // Parse imports from this file
        final fileImports = await _parseImports(entity, projectRoot);
        for (final import in fileImports) {
          edges.add(ImportEdge(from: relativePath, to: import));
        }

        // Emit partial update for real-time UI
        if (nodes.length % 5 == 0) {
          _projectMapController.add(
            ProjectMap(nodes: List.from(nodes), edges: List.from(edges), fileAnalysis: Map.from(fileAnalysis)),
          );
        }
      }
    }
  }

  Future<FileAnalysis> _analyzeFile(File file, String projectRoot, String relativePath) async {
    try {
      final content = await file.readAsString();
      final lines = content.split('\n');
      final lineCount = lines.length;

      // Determine file type based on path and content
      final fileType = _determineFileType(relativePath, content);
      final description = _generateDescription(relativePath, fileType, content);

      // Extract imports and exports
      final imports = await _parseImports(file, projectRoot);
      final exports = _parseExports(content);

      final fileName = relativePath.split('/').last;

      return FileAnalysis(
        filePath: relativePath,
        fileName: fileName,
        fileType: fileType,
        description: description,
        lineCount: lineCount,
        imports: imports,
        exports: exports,
      );
    } catch (e) {
      print('❌ Failed to analyze file $relativePath: $e');
      return FileAnalysis(
        filePath: relativePath,
        fileName: relativePath.split('/').last,
        fileType: 'unknown',
        description: 'Failed to analyze file',
        lineCount: 0,
        imports: [],
        exports: [],
      );
    }
  }

  String _determineFileType(String filePath, String content) {
    final segments = filePath.split('/');

    // Check directory structure first (Flutter conventions)
    if (segments.contains('screens')) return 'screen';
    if (segments.contains('widgets')) return 'widget';
    if (segments.contains('models')) return 'model';
    if (segments.contains('services')) return 'service';
    if (segments.contains('providers')) return 'provider';
    if (segments.contains('utils') || segments.contains('helpers')) return 'utility';
    if (segments.contains('constants')) return 'constants';

    // Check content patterns
    if (content.contains('class') && content.contains('extends StatefulWidget')) return 'stateful_widget';
    if (content.contains('class') && content.contains('extends StatelessWidget')) return 'stateless_widget';
    if (content.contains('class') && content.contains('Bloc')) return 'bloc';
    if (content.contains('class') && content.contains('extends ChangeNotifier')) return 'provider';
    if (content.contains('class') && content.contains('extends Model')) return 'model';
    if (content.contains('final String') && content.contains('=')) return 'constants';

    return 'general_dart';
  }

  String _generateDescription(String filePath, String fileType, String content) {
    final fileName = filePath.split('/').last.replaceAll('.dart', '');

    // Generate description based on file type and content
    switch (fileType) {
      case 'screen':
        return '🎨 Screen/Page widget that represents a full-screen UI. Contains navigation logic, form handling, and main user interactions for the "$fileName" feature.';
      case 'widget':
        return '🧩 Reusable UI widget. Responsible for rendering specific UI components. Can be stateful or stateless depending on logic complexity.';
      case 'stateful_widget':
        return '⚙️ Stateful widget with mutable state. Manages local UI state and lifecycle methods for dynamic behavior.';
      case 'stateless_widget':
        return '⚡ Stateless widget. Pure presentational component that rebuilds based on parent state changes.';
      case 'model':
        return '📦 Data model class. Represents domain entities and business logic structures. Often used for data serialization/deserialization.';
      case 'service':
        return '🔧 Business logic service. Handles API calls, database operations, or other backend integration for "$fileName".';
      case 'provider':
        return '📡 State management provider (using Provider or GetX). Manages application-wide state and notifies listeners of changes.';
      case 'bloc':
        return '🔄 BLoC (Business Logic Component). Separates business logic from UI using streams. Handles complex state management.';
      case 'utility':
        return '🛠️ Utility/Helper functions. Provides common functionality and helper methods used across the application.';
      case 'constants':
        return '📍 Constants definition file. Contains application-wide constants like colors, strings, numbers, and configuration values.';
      default:
        return '📄 Dart source file. General-purpose code file - part of the project\'s codebase. Role can be determined by examining imports and classes.';
    }
  }

  List<String> _parseExports(String content) {
    final exports = <String>[];
    final exportRegex = RegExp(r'''export\s+['"](.+?)['"]\s*;''');

    for (final match in exportRegex.allMatches(content)) {
      exports.add(match.group(1)!);
    }

    return exports;
  }

  String _getRelativePath(String fullPath, String projectRoot) {
    return fullPath.replaceFirst('$projectRoot/lib/', '');
  }

  Future<List<String>> _parseImports(File file, String projectRoot) async {
    final imports = <String>[];

    try {
      final content = await file.readAsString();
      final lines = content.split('\n');

      // Regex for local imports (relative or package:project_name)
      final importRegex = RegExp(r'''import\s+['"](.+?)['"]\s*;''');

      for (final line in lines) {
        final match = importRegex.firstMatch(line);
        if (match != null) {
          final importPath = match.group(1)!;

          // Only include local imports (not external packages)
          if (_isLocalImport(importPath, projectRoot)) {
            imports.add(_normalizeImportPath(importPath, projectRoot));
          }
        }
      }
    } catch (e) {
      print('❌ Failed to parse imports from ${file.path}: $e');
    }

    return imports;
  }

  bool _isLocalImport(String importPath, String projectRoot) {
    // Check for relative imports (../ or ./)
    if (importPath.startsWith('../') || importPath.startsWith('./')) {
      return true;
    }

    // Check for package: imports that match the project name
    if (importPath.startsWith('package:')) {
      final projectName = _getProjectName(projectRoot);
      return importPath.startsWith('package:$projectName/');
    }

    return false;
  }

  String _normalizeImportPath(String importPath, String projectRoot) {
    // Convert package: imports to relative paths
    if (importPath.startsWith('package:')) {
      final projectName = _getProjectName(projectRoot);
      final relativePath = importPath.replaceFirst('package:$projectName/', '');
      return relativePath;
    }

    // Handle relative imports by resolving them
    if (importPath.startsWith('../') || importPath.startsWith('./')) {
      // For simplicity, return as-is for now
      // A full implementation would resolve relative paths
      return importPath;
    }

    return importPath;
  }

  String _getProjectName(String projectRoot) {
    try {
      final pubspecFile = File('$projectRoot/pubspec.yaml');
      if (pubspecFile.existsSync()) {
        final content = pubspecFile.readAsStringSync();
        final nameMatch = RegExp(r'name:\s*(\w+)').firstMatch(content);
        if (nameMatch != null) {
          return nameMatch.group(1)!;
        }
      }
    } catch (e) {
      print('Failed to read project name: $e');
    }

    // Fallback: use directory name
    return projectRoot.split(Platform.pathSeparator).last;
  }

  void dispose() {
    _projectMapController.close();
    try {
      _lintController.close();
    } catch (e) {
      // ignore
    }
  }
}
