import 'dart:io';
import 'dart:convert';

class LintIssue {
  final String file;
  final int line;
  final String message;

  LintIssue({required this.file, required this.line, required this.message});
}

class LintService {
  Future<List<LintIssue>> runDartAnalyze(String projectRoot) async {
    final issues = <LintIssue>[];
    try {
      final proc = await Process.start('dart', ['analyze', '--format=json'], workingDirectory: projectRoot);
      final out = await proc.stdout.transform(utf8.decoder).join();
      final err = await proc.stderr.transform(utf8.decoder).join();
      final code = await proc.exitCode;
      if (out.isEmpty) return issues;

      // Parse JSON output - may be array or object
      try {
        final data = jsonDecode(out);
        if (data is Map && data['issues'] != null) {
          for (final item in data['issues']) {
            final file = item['location']?['file'] ?? '';
            final line = item['location']?['range'] != null ? item['location']['range']['start']['line'] + 1 : 0;
            final message = item['message'] ?? '';
            issues.add(LintIssue(file: file, line: line, message: message));
          }
        }
      } catch (e) {
        // Non-JSON or different format - ignore for now
      }
    } catch (e) {
      // Not fatal - return empty list
    }
    return issues;
  }
}
