import 'package:beacon_project/viewmodels/dashboard_view_model.dart';
import 'package:beacon_project/viewmodels/resource_viewmodel.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';


class TextToSpeechService {
  final FlutterTts _flutterTts = FlutterTts();

  Future<void> speak(String text) async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }

  Future<void> readResourcePage(ResourceViewModel viewModel) async {
    String text = "You are on the Resources Page. "
        "The selected tab is ${viewModel.getSelectedTab.toString().split('.').last}. "
        "There are ${viewModel.getResources.length} resources available. "
        "You have ${viewModel.getConnectedDevices.length} connected devices.";
    for (final resource in viewModel.getResources) {
      text += "Resource name: ${resource.resourceName}. ";
      text += "Resource description: ${resource.resourceDescription}. ";
      text += "Resource type: ${resource.resourceType}. ";
    }

    await speak(text);
  }

  Future<void> readDashboardPage(DashboardViewModel viewModel) async {
    String text = "You are on the Dashboard Page. "
        "You have started the communication as a ${viewModel.mode}. "
        "There are ${viewModel.availableDevices.length} available devices."
        "You have ${viewModel.connectedDevices.length} connected devices.";


    await speak(text);
  }

}



class TtsButton extends StatelessWidget {

  const TtsButton({super.key,this.resourceViewModel,this.dashboardViewModel});

  final ResourceViewModel? resourceViewModel;
  final DashboardViewModel? dashboardViewModel;


  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Text to Speech',
      icon: const Icon(Icons.record_voice_over),
      onPressed: () {
   final String routeName = GoRouterState.of(context).uri.path;
   debugPrint('[TtsButton] Current route path: $routeName');
        final ttsService = TextToSpeechService();
        
        if (routeName.contains('resources')) {
          ttsService.readResourcePage(resourceViewModel!);
        } else if (routeName.contains('dashboard')) {
          ttsService.readDashboardPage(dashboardViewModel!);
        }
      },
    );
  }
}