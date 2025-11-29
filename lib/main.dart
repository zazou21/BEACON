import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
<<<<<<< HEAD
import 'package:provider/provider.dart';
import 'theme.dart';
import 'screens/dashboard_page.dart';
import 'viewmodels/dashboard_view_model.dart';
import 'screens/chat_page.dart';
import 'screens/resources_page.dart';
import 'screens/profile_page.dart';
import 'services/voice_commands.dart';
import 'services/db_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const BeaconApp());
}

class BeaconApp extends StatefulWidget {
  const BeaconApp({super.key});

  @override
  State<BeaconApp> createState() => _BeaconAppState();
}

class _BeaconAppState extends State<BeaconApp> {
  bool isDarkMode = false;

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
            // Parse mode from query parameters
            final modeParam = state.uri.queryParameters['mode'] ?? 'browse';
            print('[Router] Dashboard mode param: $modeParam');
            late final DashboardMode mode;
            if (modeParam == 'joiner') {
              mode = DashboardMode.joiner;
            } else if (modeParam == 'initiator') {
              mode = DashboardMode.initiator;
            } else {
              mode = DashboardMode.joiner; // default fallback
            }
            return DashboardPage(mode: mode);
          },
        ),

        GoRoute(
          path: '/chat',
          name: 'chat',
          builder: (context, state) => ChatPage(macAddress: ''),
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
    // Find the BeaconApp state to toggle the theme
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

void onFlush() async{
  final db=await DBService().database;
  await db.delete('devices');
  await db.delete('clusters');
  await db.delete('cluster_members');

}

// ---------------------------
// DB Flush Button
// ---------------------------


// ---------------------------
// Landing Page
// ---------------------------
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _startNew(BuildContext context) {
    // Navigate to chat in "start" mode
    // Navigate to dashboard in "initiator" mode
    context.go('/dashboard?mode=initiator');
  }

  void _joinExisting(BuildContext context) {
    // Navigate to dashboard in "joiner" mode
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
          // Theme toggle in Landing AppBar
          ThemeToggleButton(),
          DbFlushButton(onFlush: onFlush)
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
=======
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';
import 'screens/dashboard_page.dart';
import 'screens/chat_page.dart';
import 'screens/resources_page.dart';
import 'screens/profile_page.dart';
import 'services/voice_commands.dart';
import 'services/db_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure DB is initialized early (optional)
  await DBService().database;

  final prefs = await SharedPreferences.getInstance();
  final profileCompleted = prefs.getBool('profileCompleted') ?? false;

  runApp(BeaconApp(profileCompleted: profileCompleted));
}

class BeaconApp extends StatefulWidget {
  final bool profileCompleted;
  const BeaconApp({super.key, required this.profileCompleted});

  @override
  State<BeaconApp> createState() => _BeaconAppState();
}

class _BeaconAppState extends State<BeaconApp> {
  bool isDarkMode = false;

  void toggleTheme() => setState(() => isDarkMode = !isDarkMode);

  ThemeData get currentTheme => isDarkMode ? darkTheme() : lightTheme();

  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: widget.profileCompleted ? '/dashboard' : '/profile',
      routes: [
        GoRoute(
          path: '/',
          name: 'landing',
          builder: (context, state) => const LandingPage(),
        ),

        // ShellRoute for bottom navigation
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
              path: '/chat',
              name: 'chat',
              builder: (context, state) => const ChatPage(macAddress: ''),
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
  }

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

// ---------------------------
// Theme toggle and DB flush (kept as before)
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

// DbFlushButton and onFlush preserved
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
  await db.delete('profile');
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('profileCompleted');
}

// ---------------------------
// Landing Page
// ---------------------------
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _startNew(BuildContext context) {
    // Navigate to chat in "start" mode
    context.go('/dashboard?mode=initiator');
  }

  void _joinExisting(BuildContext context) {
    // Navigate to dashboard in "join" mode
    context.go('/dashboard?mode=joiner');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BEACON'),
        centerTitle: true,
        actions: const [
          // Theme toggle in Landing AppBar
          ThemeToggleButton(),
          DbFlushButton(onFlush: onFlush)
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
>>>>>>> Korkor
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
        VoiceCommandWidget(),
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
<<<<<<< HEAD
// HomeShell with Bottom Navigation
=======
// HomeShell with Bottom Navigation (now with AppBar + Theme toggle)
>>>>>>> Korkor
// ---------------------------
class HomeShell extends StatefulWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
<<<<<<< HEAD
  Future<DashboardMode?> getSavedDashboardMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('dashboard_mode');

    if (saved == null) return null;
    return DashboardMode.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => DashboardMode.joiner,
    );
  }

=======
>>>>>>> Korkor
  final Map<String, int> _locationToIndex = {
    '/dashboard': 0,
    '/chat': 1,
    '/resources': 2,
    '/profile': 3,
<<<<<<< HEAD
    '/': 4,
=======
>>>>>>> Korkor
  };

  final Map<int, String> _indexToTitle = {
    0: 'Dashboard',
    1: 'Chat',
    2: 'Resources',
    3: 'Profile',
<<<<<<< HEAD
    4: 'Landing',
=======
>>>>>>> Korkor
  };

  int _currentIndex = 0;

<<<<<<< HEAD
  void _onTap(int index) async {
    final mode = await getSavedDashboardMode();
    print('Navigating to index $index with mode ${mode?.name}');
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        if (mode != null) {
          context.go('/dashboard?mode=${mode.name}');
        } else {
          context.go('/dashboard');
        }
=======
  void _onTap(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go('/dashboard');
>>>>>>> Korkor
        break;
      case 1:
        context.go('/chat');
        break;
      case 2:
        context.go('/resources');
        break;
      case 3:
        context.go('/profile');
        break;
<<<<<<< HEAD
      case 3:
        context.go('/');
        break;
=======
>>>>>>> Korkor
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
<<<<<<< HEAD
  
=======

>>>>>>> Korkor
  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    final title = _titleForLocation(loc);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const [
          ThemeToggleButton(),
<<<<<<< HEAD
          DbFlushButton(onFlush: onFlush),
=======
          DbFlushButton(onFlush: onFlush) // shared toggle here so all inner pages show it
>>>>>>> Korkor
        ],
      ),
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chat'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: 'Resources',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
<<<<<<< HEAD
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Landing'),
=======
>>>>>>> Korkor
        ],
      ),
    );
  }
}
