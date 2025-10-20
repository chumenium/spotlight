import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/auth_provider.dart';
import 'widgets/bottom_navigation_bar.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/create_post_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const SpotLightApp());
}

class SpotLightApp extends StatelessWidget {
  const SpotLightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => NavigationProvider()),
        ChangeNotifierProvider(create: (context) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'SpotLight',
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.orange,
          primaryColor: const Color(0xFFFF6B35),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF6B35),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            // ログイン状態に応じて画面を切り替え
            if (authProvider.isLoggedIn) {
              return const MainScreen();
            } else {
              return const LoginScreen();
            }
          },
        ),
      ),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, _) {
        return Scaffold(
          body: IndexedStack(
            index: navigationProvider.currentIndex,
            children: const [
              HomeScreen(),
              SearchScreen(),
              CreatePostScreen(),
              NotificationsScreen(),
              ProfileScreen(),
            ],
          ),
          bottomNavigationBar: CustomBottomNavigationBar(
            currentIndex: navigationProvider.currentIndex,
            onTap: (index) {
              navigationProvider.setCurrentIndex(index);
            },
          ),
        );
      },
    );
  }
}
