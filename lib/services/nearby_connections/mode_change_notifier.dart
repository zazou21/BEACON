import 'dart:async';
import 'package:beacon_project/models/dashboard_mode.dart';

class ModeChangeNotifier {
  static final ModeChangeNotifier _instance = ModeChangeNotifier._internal();
  factory ModeChangeNotifier() => _instance;
  ModeChangeNotifier._internal();

  final _modeChangeController = StreamController<DashboardMode>.broadcast();
  Stream<DashboardMode> get modeChangeStream => _modeChangeController.stream;

  void notifyModeChange(DashboardMode newMode) {
    print('[ModeChangeNotifier] Notifying mode change to: $newMode');
    _modeChangeController.add(newMode);
  }

  void dispose() {
    _modeChangeController.close();
  }
}
