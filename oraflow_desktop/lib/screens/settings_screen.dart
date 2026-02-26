import 'package:flutter/material.dart';
import '../services/config_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isMigrated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; });
    final key = await ConfigService.getApiKey();
    // determine if plaintext file existed (simple heuristic)
    final fileKey = ConfigService.getApiKeySync();
    setState(() {
      _keyController.text = key;
      _isMigrated = fileKey.isEmpty;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final k = _keyController.text.trim();
    await ConfigService.setApiKey(k);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API key saved')));
    await _load();
  }

  Future<void> _clear() async {
    await ConfigService.setApiKey('');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API key cleared')));
    await _load();
  }

  Future<void> _migrate() async {
    await ConfigService.migrateFileKeyIntoSecureStorage();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Migration attempted')));
    await _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Color(0xFF00F5FF))),
        backgroundColor: const Color(0xFF0B0E14),
      ),
      backgroundColor: const Color(0xFF0B0E14),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text('API Key', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _keyController,
                    decoration: const InputDecoration(
                      hintText: 'Enter API key',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5FF), foregroundColor: const Color(0xFF0B0E14)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _clear,
                        child: const Text('Clear Key'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('Migration status: ', style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 8),
                      Text(_isMigrated ? 'Migrated' : 'Pending', style: const TextStyle(color: Colors.white)),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _migrate,
                        child: const Text('Re-run Migration'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 12),
                  const Text('Notes', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  const Text('The key is stored in OS secure storage where available. Clearing the key will remove it from both secure storage and fallback file.', style: TextStyle(color: Colors.white70)),
                ],
              ),
      ),
    );
  }
}
