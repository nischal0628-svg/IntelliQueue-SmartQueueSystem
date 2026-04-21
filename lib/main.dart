import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intelliqueue/feature/login/view/login_page.dart';
import 'package:intelliqueue/feature/home/view/home_page.dart'; // Your homepage
import 'package:intelliqueue/local_auth/local_auth.dart';
import 'package:intelliqueue/ui/app_colors.dart';
import 'package:intelliqueue/portal/view/portal_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await LocalAuth.init();
    LocalAuth.startQueueSimulation();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Web portal must not depend on LocalAuth/Hive boxes.
    if (kIsWeb) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "IntelliQueue",
        themeMode: ThemeMode.light,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.headerBlue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const PortalGate(),
      );
    }

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (_, __) {
        return ValueListenableBuilder(
          valueListenable: LocalAuth.sessionListenable(),
          builder: (context, _, __) {
            final themePref = LocalAuth.themeModePreference();
            final accent = LocalAuth.accentColorValue();
            final seed = Color(accent ?? AppColors.headerBlue.toARGB32());

            final themeMode = switch (themePref) {
              'light' => ThemeMode.light,
              'dark' => ThemeMode.dark,
              _ => ThemeMode.system,
            };

            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: "IntelliQueue",
              themeMode: themeMode,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
                useMaterial3: true,
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
                useMaterial3: true,
              ),
              home: Builder(
                builder: (context) {
                  if (kIsWeb) return const PortalGate();
                  final phone = LocalAuth.currentUserPhone();
                  if (phone != null) return const HomePage();
                  return const LoginPage();
                },
              ),
            );
          },
        );
      },
    );
  }
}
