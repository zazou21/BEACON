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

// Global login state - loaded before router creation
bool _isLoggedIn = false;

// Function to update login state from other files
void setLoggedIn(bool value) {
  _isLoggedIn = value;
  print('[Main] _isLoggedIn updated to: $value');
}

// Global pending dashboard mode - set when user chooses before setup
String _pendingDashboardMode = 'joiner';

// Global saved dashboard mode - loaded from prefs
String _savedDashboardMode = 'joiner';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService().initialize();

  // Setup notification tap handler
  NotificationService.onNotificationTapped = (String deviceUuid) {
    _pendingChatNavigation = deviceUuid;
    _handleNotificationNavigation();
  };

  // Setup snackbar handler for foreground messages
  NotificationService.onShowSnackbar = (String deviceName, String message) {
    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deviceName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: const Color.fromARGB(255, 10, 51, 85),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  };
  final prefs = await SharedPreferences.getInstance();
  _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  _savedDashboardMode = prefs.getString('dashboard_mode') ?? 'joiner';
  print('[Main] Loaded is_logged_in: $_isLoggedIn, dashboard_mode: $_savedDashboardMode');
  
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
  String mode = 'joiner';
  

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
    // Update notification service about app lifecycle
    NotificationService().updateAppLifecycleState(state);

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
  redirect: (context, state) {
    final matchedLoc = state.matchedLocation;
    final fullLoc = state.uri.toString();
    
    print('[Router Redirect] matchedLocation: $matchedLoc');
    print('[Router Redirect] fullUri: $fullLoc');
    print('[Router Redirect] is_logged_in (cached): $_isLoggedIn');
    print('[Router Redirect] savedDashboardMode: $_savedDashboardMode');
    
    final isProtectedRoute = matchedLoc.contains('/dashboard') ||
        matchedLoc.contains('/chat') ||
        matchedLoc.contains('/resources');
    
    // Allow access to landing if explicitly requested (force=true)
    final forceParam = state.uri.queryParameters['force'];
    final forceLanding = forceParam == 'true';
    
    // If logged in and on landing page (without force), redirect to dashboard
    if (_isLoggedIn && matchedLoc == '/' && !forceLanding) {
      print('[Router Redirect] REDIRECTING to /dashboard?mode=$_savedDashboardMode');
      return '/dashboard?mode=$_savedDashboardMode';
    }
    
    // If not logged in and trying to access protected route, redirect to setup page
    if (!_isLoggedIn && isProtectedRoute) {
      print('[Router Redirect] REDIRECTING to /setup');
      return '/setup';
    }
    
    print('[Router Redirect] No redirect needed');
    return null; // No redirect needed
  },
  routes: [
    GoRoute(
      path: '/',
      name: 'landing',
      builder: (context, state) => const LandingPage(),
    ),

    
    GoRoute(
      path: '/chat',
      name: 'chat',
      builder: (context, state) {
        final deviceUuid = state.uri.queryParameters['deviceUuid'];
        final clusterId = state.uri.queryParameters['clusterId'];
        final isGroupChat = clusterId != null;
        return ChatPage(
          deviceUuid: deviceUuid,
          clusterId: clusterId,
          isGroupChat: isGroupChat,
        );
      },
    ),

    // Top-level setup route for first-time profile setup (no bottom nav)
    GoRoute(
      path: '/setup',
      name: 'setup',
      builder: (context, state) {
        return const UserProfilePage(isFirstTime: true);
      },
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
          builder: (context, state) => const UserProfilePage(isFirstTime: false),
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
  await db.delete('chat_message');
}

// ---------------------------
// Landing Page
// ---------------------------
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _startNew(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in');
    if (isLoggedIn == true) {
      context.go('/dashboard?mode=initiator');
    } else {
      // Save pending mode for after profile setup
      _pendingDashboardMode = 'initiator';
      await prefs.setString('dashboard_mode', 'initiator');
      context.go('/setup');
    }
  }

  void _joinExisting(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in');
    if (isLoggedIn == true) {
      context.go('/dashboard?mode=joiner');
    } else {
      // Save pending mode for after profile setup
      _pendingDashboardMode = 'joiner';
      await prefs.setString('dashboard_mode', 'joiner');
      context.go('/setup');
    }
  }

  Future<void> deleteSavedDashboardMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dashboard_mode');
    await prefs.setBool('is_logged_in', false);
    _isLoggedIn = false; // Update global cached value
    print('[LandingPage] Reset is_logged_in to false');
  }

  @override
  Widget build(BuildContext context) {
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
        context.go('/?force=true');
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
