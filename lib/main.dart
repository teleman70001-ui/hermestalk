import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_bubble.dart';
import 'chat_message.dart';
import 'settings_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Zone global — tangkap SEMUA async error (Future tidak tertangkap)
  runZonedGuarded(() {
    // Error boundary — biar app nggak crash diam-diam di release
    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('FlutterError: ${details.exception}\n${details.stack}');
      FlutterError.presentError(details);
    };
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 12),
              Text('Terjadi error aplikasi.\nHubungi developer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red)),
            ]),
          ),
        ),
      );
    };

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    runApp(const HermesTalkApp());
  }, (error, stack) {
    debugPrint('Zone Fatal Error: $error\n$stack');
    FlutterError.dumpErrorToConsole(FlutterErrorDetails(exception: error, stack: stack));
  });
}

class HermesTalkApp extends StatelessWidget {
  const HermesTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HermesTalk',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF00BFA5),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF00BFA5),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const TalkPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TalkPage extends StatefulWidget {
  const TalkPage({super.key});

  @override
  State<TalkPage> createState() => _TalkPageState();
}

class _TalkPageState extends State<TalkPage> {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;
  bool _loading = false;
  final List<ChatMessage> _messages = [];
  final _textCtrl = TextEditingController();

  String _endpoint = 'http://168.110.208.118:20128/v1/chat/completions';
  String _apiKey = '';
  String _model = 'FREE';

  @override
  void initState() {
    super.initState();
    // Inisialisasi async di post-frame — hindari crash NoSuchMethodError di release
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// Lazy-init TTS + load settings
  Future<void> _bootstrap() async {
    await _loadSettings();
    // Jangan auto-init TTS — baru init saat user minta bicara
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _endpoint = prefs.getString('endpoint') ?? 'http://168.110.208.118:20128/v1/chat/completions';
      _apiKey = prefs.getString('api_key') ?? '';
      _model = prefs.getString('model') ?? 'FREE';
    });
  }

  // --- TTS ---
  bool _ttsReady = false;

  Future<bool> _ensureTts() async {
    if (_ttsReady) return true;
    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() => setState(() => _speaking = false));
      _ttsReady = true;
      return true;
    } catch (e) {
      debugPrint('TTS init failed: $e');
      _ttsReady = false;
      return false;
    }
  }

  void _speak(String text) async {
    if (!_ttsReady) {
      final ok = await _ensureTts();
      if (!ok) return;
    }
    setState(() => _speaking = true);
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
      if (mounted) setState(() => _speaking = false);
    }
  }

  void _stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    if (mounted) setState(() => _speaking = false);
  }

  // --- Chat flow ---
  void _sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _messages.add(ChatMessage(text: msg, isUser: true));
      _textCtrl.clear();
    });

    try {
      final url = Uri.parse(_endpoint);
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (_apiKey.isNotEmpty) 'Authorization': _apiKey,
        },
        body: jsonEncode({
          'model': _model,
          'messages': _buildChatHistory(),
          'stream': false,
          'max_tokens': 2048,
        }),
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw FormatException('HTTP ${resp.statusCode}: ${resp.body}');
      }

      final data = jsonDecode(resp.body);
      final reply = (data['choices'][0]['message']['content'] as String).trim();

      setState(() => _messages.add(ChatMessage(text: reply, isUser: false)));
      _speak(reply);
    } catch (e, st) {
      debugPrint('HTTP error: $e\n$st');
      if (mounted) {
        setState(() => _messages.add(ChatMessage(text: 'Error: $e', isUser: false)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _buildChatHistory() =>
      _messages.map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text}).toList();

  void _openSettings() {
    showDialog(
      context: context,
      builder: (_) => SettingsDialog(
        endpoint: _endpoint,
        apiKey: _apiKey,
        model: _model,
        onSave: (ep, key, mdl) {
          setState(() {
            _endpoint = ep;
            _apiKey = key;
            _model = mdl;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HermesTalk'),
        centerTitle: true,
        actions: [
          if (_model.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(_model,
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              ),
            ),
          IconButton(icon: const Icon(Icons.settings), onPressed: _openSettings),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.chat, size: 64, color: Colors.teal),
                      SizedBox(height: 12),
                      Text('Ketik pesan atau pencet mikrofon\nuntuk ngobrol sama Hermes Agent',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                    ]),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => ChatBubble(
                      message: _messages[i],
                      isLoading: _loading && i == _messages.length - 1 && !_messages[i].isUser,
                    ),
                  ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(children: [
                  SizedBox(width: 8, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Hermes mikir...'),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  onSubmitted: _sendMessage,
                  decoration: InputDecoration(
                    hintText: 'Ketik pesan... (model: $_model)',
                    border: const OutlineInputBorder(),
                    suffixIcon: _speaking
                        ? IconButton(icon: const Icon(Icons.stop), onPressed: _stopSpeaking)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                mini: true,
                onPressed: _loading ? null : () => _sendMessage(_textCtrl.text),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
