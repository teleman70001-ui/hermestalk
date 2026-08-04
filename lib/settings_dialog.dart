import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsDialog extends StatefulWidget {
  final String endpoint;
  final String apiKey;
  final String model;
  final void Function(String endpoint, String apiKey, String model) onSave;

  const SettingsDialog({
    super.key,
    required this.endpoint,
    required this.apiKey,
    required this.model,
    required this.onSave,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final _epCtrl, _keyCtrl, _modelCtrl;

  @override
  void initState() {
    super.initState();
    _epCtrl = TextEditingController(text: widget.endpoint);
    _keyCtrl = TextEditingController(text: widget.apiKey);
    _modelCtrl = TextEditingController(text: widget.model);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pengaturan API'),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _epCtrl,
            decoration: const InputDecoration(
              labelText: 'Endpoint URL',
              hintText: 'http://your-server:8080/api/chat',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyCtrl,
            decoration: const InputDecoration(
              labelText: 'API Key / Bearer Token',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(
              labelText: 'Model',
              hintText: 'hermes-agent',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('endpoint', _epCtrl.text.trim());
            await prefs.setString('api_key', _keyCtrl.text.trim());
            await prefs.setString('model', _modelCtrl.text.trim());
            widget.onSave(_epCtrl.text.trim(), _keyCtrl.text.trim(), _modelCtrl.text.trim());
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
