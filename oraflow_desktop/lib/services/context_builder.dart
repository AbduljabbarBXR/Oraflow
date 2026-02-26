import 'dart:io';
import 'dart:async';

class ContextBuilder {
  // Read whole file content
  static Future<String> readFile(String filePath) async {
    try {
      final f = File(filePath);
      if (!await f.exists()) return '';
      return await f.readAsString();
    } catch (e) {
      return '';
    }
  }

  static List<String> extractImports(String fileContent) {
    return fileContent.split('\n')
        .where((line) => line.trim().startsWith('import '))
        .map((line) => line.trim().replaceAll('import ', '').replaceAll(';', ''))
        .toList();
  }

  static String generateSnippet(String fileContent, int line, {int context = 25}) {
    final lines = fileContent.split('\n');
    final start = (line - context - 1).clamp(0, lines.length - 1);
    final end = (line + context).clamp(0, lines.length);
    final snippet = lines.sublist(start, end);
    final buffer = StringBuffer();
    for (var i = 0; i < snippet.length; i++) {
      final actual = start + i + 1;
      final marker = actual == line ? ' >>> ' : '     ';
      buffer.writeln('${actual.toString().padLeft(4)}$marker${snippet[i]}');
    }
    return buffer.toString();
  }

  static Future<String> gitDiff(String filePath) async {
    try {
      final result = await Process.run('git', ['diff', 'HEAD', '--', filePath]);
      if (result.exitCode == 0) return result.stdout.toString().trim();
      return '';
    } catch (e) {
      return '';
    }
  }

  static Future<String> projectStructure(String filePath, {int limit = 20}) async {
    try {
      final projectRoot = filePath.contains('lib/') ? filePath.split('lib/').first : Directory.current.path;
      // Use Dart to walk files (cross-platform)
      final dir = Directory('$projectRoot/lib');
      if (!await dir.exists()) return '';
      final files = <String>[];
      await for (final f in dir.list(recursive: true, followLinks: false)) {
        if (f is File && f.path.endsWith('.dart')) {
          files.add(f.path.replaceFirst(projectRoot, ''));
          if (files.length >= limit) break;
        }
      }
      return files.join('\n');
    } catch (e) {
      return '';
    }
  }

  static String detectWidgetType(List<String> lines, int line) {
    for (int i = line - 1; i >= 0 && i > line - 40; i--) {
      final content = lines[i].trim();
      if (content.contains('extends StatefulWidget')) return 'StatefulWidget';
      if (content.contains('extends StatelessWidget')) return 'StatelessWidget';
      if (content.contains('extends InheritedWidget')) return 'InheritedWidget';
    }
    final errorLine = lines.length >= line ? lines[line - 1] : '';
    if (errorLine.contains('setState') || errorLine.contains('build')) return 'StatefulWidget';
    return 'Unknown';
  }
}
