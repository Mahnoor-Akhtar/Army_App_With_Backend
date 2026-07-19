import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/supabase_service.dart';
import 'services/personnel_data_manager.dart';
import 'views/splash_screen.dart';
import 'views/login_screen.dart';
import 'views/dashboard_screen.dart';
import 'viewmodels/app_viewmodel.dart';
import 'viewmodels/login_viewmodel.dart';
import 'viewmodels/dashboard_viewmodel.dart';
import 'viewmodels/nominal_roll_viewmodel.dart';
import 'viewmodels/analysis_viewmodel.dart';
import 'viewmodels/edit_tab_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SupabaseService().initialize();
  
  final prefs = await SharedPreferences.getInstance();
  PersonnelDataManager().init(prefs);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: PersonnelDataManager()),
        ChangeNotifierProvider(create: (_) => AppViewModel()),
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => DashboardViewModel()),
        ChangeNotifierProvider(create: (_) => NominalRollViewModel()),
        ChangeNotifierProvider(create: (_) => AnalysisViewModel()),
        ChangeNotifierProvider(create: (_) => EditTabViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appVM = context.watch<AppViewModel>();
    final isDark = appVM.isDarkMode;

    if (!appVM.isInitialized) {
      // Show loading indicator while initializing
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: isDark ? Colors.white : const Color(0xFF0C5A32),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '117 SP Regt.',
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0C5A32),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0C5A32),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: appVM.showSplash
          ? SplashScreen(
              onFinish: () => context.read<AppViewModel>().onSplashFinished(),
            )
          : !appVM.isLoggedIn
              ? LoginScreen(
                  onLoginSuccess: () =>
                      context.read<AppViewModel>().onLoginSuccess(),
                  isDarkMode: isDark,
                  onToggleTheme: () =>
                      context.read<AppViewModel>().toggleTheme(),
                )
              : DashboardScreen(
                  onLogout: () => context.read<AppViewModel>().onLogout(),
                  isDarkMode: isDark,
                  onToggleTheme: () =>
                      context.read<AppViewModel>().toggleTheme(),
                ),
    );
  }
}
