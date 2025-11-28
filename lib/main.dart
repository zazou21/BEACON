import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:go_router/go_router.dart';
import 'theme.dart';
import 'screens/dashboard_page.dart';
import 'screens/chat_page.dart';
import 'screens/resources_page.dart';
import 'screens/profile_page.dart';
import 'services/voice_commands.dart';
import 'services/db_service.dart';

void main() {
  runApp(const BeaconApp());
}
=======
import 'package:beacon_project/theme.dart';
import 'package:beacon_project/screens/resources_page.dart';

void main() => runApp(const MyApp());
>>>>>>> 99fbd7599c6056eca4408b936583473a9d0e3fb0

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
<<<<<<< HEAD
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
          builder: (context, state) => const ChatPage(macAddress:'' ),
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
// HomeShell with Bottom Navigation (now with AppBar + Theme toggle)
// ---------------------------
class HomeShell extends StatefulWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final Map<String, int> _locationToIndex = {
    '/dashboard': 0,
    '/chat': 1,
    '/resources': 2,
    '/profile': 3,
  };

  final Map<int, String> _indexToTitle = {
    0: 'Dashboard',
    1: 'Chat',
    2: 'Resources',
    3: 'Profile',
  };

  int _currentIndex = 0;

  void _onTap(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go('/dashboard');
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
          DbFlushButton(onFlush: onFlush) // shared toggle here so all inner pages show it
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
        ],
      ),
    );
  }
}
=======
    return MaterialApp(
      title: 'Beacon Project',
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: ThemeMode.system,
      home: const ResourcePage(),
    );
  }
}
>>>>>>> 99fbd7599c6056eca4408b936583473a9d0e3fb0
