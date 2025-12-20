import 'package:beacon_project/services/text_to_speech.dart';
import 'package:beacon_project/viewmodels/dashboard_view_model.dart';
import 'package:beacon_project/viewmodels/resource_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'screens/dashboard_page.dart';
import 'screens/chat_page.dart';
import 'screens/resources_page.dart';
import 'screens/profile_page.dart';
import 'services/voice_commands.dart';
import 'services/db_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beacon_project/models/dashboard_mode.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:beacon_project/services/notification_service.dart';

// Global navigation key for navigation without context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global variable to store pending navigation from notifications
String? _pendingChatNavigation;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService().initialize();

  // Setup notification tap handler
  NotificationService.onNotificationTapped = (String deviceUuid) {
    _pendingChatNavigation = deviceUuid;
    _handleNotificationNavigation();
  };

  runApp(const BeaconApp());
}

/// Navigate to chat page when notification is tapped
void _handleNotificationNavigation() {
  if (_pendingChatNavigation != null && navigatorKey.currentContext != null) {
    final deviceUuid = _pendingChatNavigation!;
    _pendingChatNavigation = null;

    // Get the appropriate beacon instance
    _getBeaconInstance().then((beacon) {
      if (beacon != null && navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).push(
          MaterialPageRoute(
            builder: (context) =>
                ChatPage(deviceUuid: deviceUuid, nearby: beacon),
          ),
        );
      }
    });
  }
}

/// Get the appropriate beacon singleton instance based on saved mode
Future<NearbyConnectionsBase?> _getBeaconInstance() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('dashboard_mode') ?? 'joiner';
    final isInitiator = modeStr == 'initiator';

    return isInitiator
        ? NearbyConnectionsInitiator()
        : NearbyConnectionsJoiner();
  } catch (e) {
    debugPrint('[Navigation] Error getting beacon instance: $e');
    return null;
  }
}

class BeaconApp extends StatefulWidget {
  const BeaconApp({super.key});

  @override
  State<BeaconApp> createState() => _BeaconAppState();
}

class _BeaconAppState extends State<BeaconApp> with WidgetsBindingObserver {
  bool isDarkMode = false;
  NearbyConnectionsBase? _beacon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      print('[App Lifecycle] App paused - marking offline');
      _markOffline();
    } else if (state == AppLifecycleState.resumed) {
      print('[App Lifecycle] App resumed - marking online');
      _markOnline();
      // Check for pending notification navigation
      _handleNotificationNavigation();
    }
  }

  void _markOffline() async {
    if (mounted) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final modeStr = prefs.getString('dashboard_mode') ?? 'joiner';
        final isInitiator = modeStr == 'initiator';
        debugPrint(
          '[_markOffline] Dashboard mode: $modeStr, isInitiator: $isInitiator',
        );

        final beacon = isInitiator
            ? NearbyConnectionsInitiator()
            : NearbyConnectionsJoiner();

        print(
          '[App Lifecycle] Marking offline for ${beacon.connectedEndpoints.length} endpoints',
        );
        for (var endpointId in beacon.connectedEndpoints) {
          print('[App Lifecycle] Sending MARK_OFFLINE to $endpointId');
          beacon.sendMessage(endpointId, "MARK_OFFLINE", {"uuid": beacon.uuid});
        }
      } catch (e) {
        print('[App Lifecycle] Error marking offline: $e');
      }
    }
  }

  void _markOnline() async {
    if (mounted) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final modeStr = prefs.getString('dashboard_mode') ?? 'joiner';
        final isInitiator = modeStr == 'initiator';
        debugPrint(
          '[_markOnline] Dashboard mode: $modeStr, isInitiator: $isInitiator',
        );

        final beacon = isInitiator
            ? NearbyConnectionsInitiator()
            : NearbyConnectionsJoiner();

        print(
          '[App Lifecycle] Marking online for ${beacon.connectedEndpoints.length} endpoints',
        );
        for (var endpointId in beacon.connectedEndpoints) {
          print('[App Lifecycle] Sending MARK_ONLINE to $endpointId');
          beacon.sendMessage(endpointId, "MARK_ONLINE", {"uuid": beacon.uuid});
        }
      } catch (e) {
        print('[App Lifecycle] Error marking online: $e');
      }
    }
  }

  void toggleTheme() => setState(() => isDarkMode = !isDarkMode);

  ThemeData get currentTheme => isDarkMode ? darkTheme() : lightTheme();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BEACON',
      theme: currentTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

final GoRouter _router = GoRouter(
  navigatorKey: navigatorKey, // Add global key for navigation without context
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'landing',
      builder: (context, state) => const LandingPage(),
    ),

    // ShellRoute provides a persistent scaffold with BottomNavigationBar
    ShellRoute(
      builder: (context, state, child) {
        return HomeShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (context, state) {
            final modeParam = state.uri.queryParameters['mode'] ?? 'browse';
            print('[Router] Dashboard mode param: $modeParam');
            late final DashboardMode mode;
            if (modeParam == 'joiner') {
              mode = DashboardMode.joiner;
            } else if (modeParam == 'initiator') {
              mode = DashboardMode.initiator;
            } else {
              mode = DashboardMode.joiner;
            }
            return DashboardPage(mode: mode);
          },
        ),
        GoRoute(
          path: '/resources',
          name: 'resources',
          builder: (context, state) => const ResourcePage(),
        ),
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => const UserProfilePage(),
        ),
      ],
    ),
  ],
);

// ---------------------------
// Helper widget: ThemeToggleButton
// ---------------------------
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.findAncestorStateOfType<_BeaconAppState>();
    final isDark =
        appState?.isDarkMode ?? Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: isDark ? 'Switch to light' : 'Switch to dark',
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
      onPressed: () {
        if (appState != null) appState.toggleTheme();
      },
    );
  }
}

class DbFlushButton extends StatelessWidget {
  final VoidCallback onFlush;
  const DbFlushButton({super.key, required this.onFlush});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Flush Database',
      icon: const Icon(Icons.delete_forever),
      onPressed: () {
        onFlush();
      },
    );
  }
}

void onFlush() async {
  final db = await DBService().database;
  await db.delete('devices');
  await db.delete('clusters');
  await db.delete('cluster_members');
  await db.delete('chat');
  await db.delete('chat_messages');
}

// ---------------------------
// Landing Page
// ---------------------------
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _startNew(BuildContext context) {
    context.go('/dashboard?mode=initiator');
  }

  void _joinExisting(BuildContext context) {
    context.go('/dashboard?mode=joiner');
  }

  Future<void> deleteSavedDashboardMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dashboard_mode');
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      deleteSavedDashboardMode();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('BEACON'),
        centerTitle: true,
        actions: const [
          ThemeToggleButton(),
          DbFlushButton(onFlush: onFlush),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: isWide
                    ? _buildHorizontal(context)
                    : _buildVertical(context),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVertical(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_tethering, size: 96),
        const SizedBox(height: 12),
        const Text(
          'BEACON',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Offline peer-to-peer emergency communication',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _joinExisting(context),
          icon: const Icon(Icons.login),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
            child: Text('Join Existing Communication'),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _startNew(context),
          icon: const Icon(Icons.add_to_queue),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
            child: Text('Start New Communication'),
          ),
        ),
        const SizedBox(height: 24),
        VoiceCommandWidget(buttonMode: true),
      ],
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.wifi_tethering, size: 96),
              SizedBox(height: 8),
              Text(
                'BEACON',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Offline peer-to-peer emergency communication',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => _joinExisting(context),
                icon: const Icon(Icons.login),
                label: const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 14.0,
                    horizontal: 8.0,
                  ),
                  child: Text('Join Existing Communication'),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _startNew(context),
                icon: const Icon(Icons.add_to_queue),
                label: const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 14.0,
                    horizontal: 8.0,
                  ),
                  child: Text('Start New Communication'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------
// HomeShell with Bottom Navigation (Chat tab removed)
// ---------------------------
class HomeShell extends StatefulWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  Future<DashboardMode?> getSavedDashboardMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('dashboard_mode');

    if (saved == null) return null;
    return DashboardMode.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => DashboardMode.joiner,
    );
  }

  // Updated mapping - Chat tab removed (only 4 items now)
  final Map<String, int> _locationToIndex = {
    '/dashboard': 0,
    '/resources': 1,
    '/profile': 2,
    '/': 3,
  };

  final Map<int, String> _indexToTitle = {
    0: 'Dashboard',
    1: 'Resources',
    2: 'Profile',
    3: 'Landing',
  };

  int _currentIndex = 0;

  void _onTap(int index) async {
    final mode = await getSavedDashboardMode();
    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        context.go('/dashboard?mode=${mode?.name ?? 'joiner'}');
        break;
      case 1:
        context.go('/resources');
        break;
      case 2:
        context.go('/profile');
        break;
      case 3:
        context.go('/');
        break;
    }
  }

  String _titleForLocation(String loc) {
    for (final entry in _locationToIndex.entries) {
      if (loc.startsWith(entry.key)) {
        return _indexToTitle[entry.value] ?? 'BEACON';
      }
    }
    return 'BEACON';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loc = GoRouterState.of(context).uri.toString();
    for (final entry in _locationToIndex.entries) {
      if (loc.startsWith(entry.key)) {
        _currentIndex = entry.value;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final title = _titleForLocation(loc);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const [
          ThemeToggleButton(),
          DbFlushButton(onFlush: onFlush),
        ],
      ),
      body: Stack(
        children: [
          widget.child,
          Positioned(
            right: 16,
            bottom: kBottomNavigationBarHeight + 6,
            child: const VoiceCommandWidget(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: 'Resources',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Landing'),
        ],
      ),
    );
  }
}
