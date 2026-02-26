import 'dart:io';
import 'dart:convert';

class ConfigService {
  static const _fileName = 'oraflow_config.json';

  static String _configPath() {
    return '${Directory.current.path}${Platform.pathSeparator}$_fileName';
  }

  // Synchronous getter reads local file or env
  static String getApiKeySync() {
    try {
      final env = Platform.environment['ORAFLOW_API_KEY'];
      if (env != null && env.isNotEmpty) return env;

      final file = File(_configPath());
      if (!file.existsSync()) return '';
      final content = file.readAsStringSync();
      final data = jsonDecode(content) as Map<String, dynamic>;
      return (data['apiKey'] as String?) ?? '';
    } catch (e) {
      return '';
    }
  }

  // Async getter prefers env, then local file
  static Future<String> getApiKey() async {
    try {
      final env = Platform.environment['ORAFLOW_API_KEY'];
      if (env != null && env.isNotEmpty) return env;
      return getApiKeySync();
    } catch (e) {
      return '';
    }
  }

  // Persist API key to local file
  static Future<void> setApiKey(String apiKey) async {
    try {
      final file = File(_configPath());
      final data = {'apiKey': apiKey};
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      // ignore file write errors
    }
  }

  // Migration helper (no-op on plaintext-only)
  static Future<void> migrateFileKeyIntoSecureStorage() async {
    // No-op: already using plaintext file storage
  }
}
