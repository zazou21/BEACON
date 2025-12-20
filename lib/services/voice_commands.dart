import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
// Needed to access _BeaconAppState for theme toggle

class VoiceCommandWidget extends StatefulWidget {
  final VoidCallback? toggleTheme;
  final bool? buttonMode;
  final dynamic
  speechToText; // Accept any speech-to-text implementation (real or mock)

  const VoiceCommandWidget({
    super.key,
    this.toggleTheme,
    this.buttonMode,
    this.speechToText,
  });

  @override
  State<VoiceCommandWidget> createState() => _VoiceCommandWidgetState();
}

class _VoiceCommandWidgetState extends State<VoiceCommandWidget> {
  late dynamic _speech;
  bool _isListening = false;
  String _lastWords = "";

  @override
  void initState() {
    super.initState();
    _speech = widget.speechToText ?? stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print("Voice Status: $status"),
      onError: (error) => print("Voice Error: $error"),
    );

    if (!available) {
      print("Speech recognition not available on this device");
      return;
    }

    setState(() {}); // optional, just to rebuild if needed
  }

  // Start listening
  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print("Voice Status: $status"),
      onError: (error) => print("Voice Error: $error"),
    );

    if (!available) return;

    setState(() => _isListening = true);

    _speech.listen(
      onResult: (result) {
        final spoken = result.recognizedWords.toLowerCase();
        setState(() => _lastWords = spoken);
        _handleCommand(spoken);
      },
    );
  }

  // Stop listening
  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  // Command handler
  void _handleCommand(String command) {
    print("Command heard: $command");

    if (command.contains("dashboard")) context.go("/dashboard");
    if (command.contains("resources")) context.go("/resources");
    if (command.contains("profile")) context.go("/profile");
    if (command.contains("join communication"))
      context.go("/dashboard?mode=initiator");
    if (command.contains("start communication")) {
      context.go("/dashboard?mode=joiner");
    }

    if ((command.contains("dark mode") || command.contains("light mode")) &&
        widget.toggleTheme != null) {
      widget.toggleTheme!(); // Use the callback
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.buttonMode == true) {
      return Column(
        children: [
          Text(
            _isListening ? "Listening…" : "Tap mic for voice commands",
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _isListening ? _stopListening : _startListening,
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              size: 30,
              color: _isListening ? Colors.red : Colors.grey,
            ),
          ),
        ],
      );
    } else {
      return FloatingActionButton(
        onPressed: _isListening ? _stopListening : _startListening,
        backgroundColor: _isListening
            ? Colors.red
            : const Color.fromARGB(255, 102, 131, 211),
        child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      );
    }
  }
}
