import 'dart:async';

class MockSpeechToText {
  bool _initialized = false;
  bool _isListening = false;
  String _lastWords = '';

  Function? _onResult;
  Function? _onStatus;
  Function? _onError;

  Timer? _resultTimer;

  bool simulateError = false;
  String simulatedError = '';
  String nextRecognitionResult = '';

  Future<bool> initialize({
    required Function onStatus,
    required Function onError,
    dynamic onSoundLevelChange,
    bool debugLogging = false,
    dynamic finalTimeout,
  }) async {
    _onStatus = onStatus;
    _onError = onError;

    if (simulateError) {
      _onError?.call(simulatedError);
      return false;
    }

    _initialized = true;
    _onStatus?.call('init');
    return true;
  }

  Future<bool> listen({
    required Function onResult,
    String? localeId,
    Duration? listenFor,
    Duration? pauseFor,
    bool partialResults = true,
    bool onDevice = false,
    bool sampleRate = false,
    bool cancelOnError = false,
  }) async {
    if (!_initialized) return false;

    _isListening = true;
    _onResult = onResult;
    _onStatus?.call('listening');

    _resultTimer?.cancel();

    _resultTimer = Timer(const Duration(milliseconds: 500), () {
      if (_isListening && nextRecognitionResult.isNotEmpty) {
        _lastWords = nextRecognitionResult;
        final result = _MockSpeechResult(nextRecognitionResult);
        _onResult?.call(result);
      }
    });

    return true;
  }

  Future<void> stop() async {
    _resultTimer?.cancel();
    _resultTimer = null;

    if (_isListening) {
      _isListening = false;
      _onStatus?.call('done');
    }
  }

  bool get isInitialized => _initialized;
  bool get isListening => _isListening;
  String get lastRecognizedWords => _lastWords;

  void setNextRecognitionResult(String result) {
    nextRecognitionResult = result;
  }

  void setSimulateError(bool value, {String error = 'Mock error'}) {
    simulateError = value;
    simulatedError = error;
  }

  void reset() {
    _resultTimer?.cancel();
    _resultTimer = null;
    _initialized = false;
    _isListening = false;
    _lastWords = '';
    _onResult = null;
    _onStatus = null;
    _onError = null;
    simulateError = false;
    simulatedError = '';
    nextRecognitionResult = '';
  }
}

/// Minimal mock speech recognition result object
class _MockSpeechResult {
  final String recognizedWords;

  _MockSpeechResult(this.recognizedWords);
}
