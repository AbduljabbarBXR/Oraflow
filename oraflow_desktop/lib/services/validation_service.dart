import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

class ValidationService {
  /// Applies the provided edits into a temporary copy of the project located at [projectRoot]
  /// and runs `dart analyze` to ensure the edits do not introduce static analysis errors.
  ///
  /// Expected edit shape: { 'file': '<absolute path>', 'line': <int>, 'old_line_content': '<str>', 'new_line_content': '<str>' }
  static Future<bool> validateEdits(List<dynamic> edits, String projectRoot) async {
    try {
      final tempDir = await Directory.systemTemp.createTemp('oraflow_validate_');
      final tempPath = tempDir.path;

      // Copy project into temp directory (simple recursive copy)
      await _copyDirectory(Directory(projectRoot), Directory(tempPath));

      // Apply edits
      for (final e in edits) {
        final Map<String, dynamic> emap = Map<String, dynamic>.from(e as Map);
        final absFile = emap['file'] as String? ?? '';
        if (absFile.isEmpty) continue;

        // Compute relative path from projectRoot
        final rel = p.relative(absFile, from: projectRoot);
        final targetPath = p.join(tempPath, rel);
        final f = File(targetPath);
        if (!await f.exists()) {
          // If file missing in temp copy, skip
          continue;
        }

        final content = await f.readAsLines();
        final startLine = (emap['startLine'] ?? emap['line'] ?? 0) as int;
        final endLine = (emap['endLine'] ?? emap['line'] ?? startLine) as int;
        final newText = emap['newText'] as String? ?? emap['new_line_content'] as String? ?? '';

        final s = (startLine - 1).clamp(0, content.length);
        final eidx = (endLine - 1).clamp(0, content.length - 1);

        final before = content.sublist(0, s);
        final after = (eidx + 1) < content.length ? content.sublist(eidx + 1) : <String>[];
        final newLines = newText.split('\n');

        final merged = <String>[];
        merged.addAll(before);
        merged.addAll(newLines);
        merged.addAll(after);

        await f.writeAsString(merged.join('\n'));
      }

      // Run dart analyze in tempPath
      final proc = await Process.start('dart', ['analyze', '--no-fatal-infos'], workingDirectory: tempPath);
      final out = await proc.stdout.transform(utf8.decoder).join();
      final err = await proc.stderr.transform(utf8.decoder).join();
      final code = await proc.exitCode;

      // Cleanup temp dir
      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        // ignore cleanup errors
      }

      // exitCode 0 means no issues
      return code == 0;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _copyDirectory(Directory src, Directory dest) async {
    if (!await dest.exists()) {
      await dest.create(recursive: true);
    }

    await for (final entity in src.list(recursive: true, followLinks: false)) {
      final relative = p.relative(entity.path, from: src.path);
      final newPath = p.join(dest.path, relative);

      if (entity is File) {
        final newFile = File(newPath);
        await newFile.create(recursive: true);
        await entity.copy(newPath);
      } else if (entity is Directory) {
        final newDir = Directory(newPath);
        if (!await newDir.exists()) await newDir.create(recursive: true);
      }
    }
  }
}
