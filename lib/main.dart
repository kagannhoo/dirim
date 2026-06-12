import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_secrets.dart';
import 'constants/app_branding.dart';
import 'services/api_config_service.dart';
import 'services/reminder_notification_service.dart';
import 'screens/login_screen.dart';
// import 'screens/home_screen.dart'; <-- Bunu silebilirsin, artık MainDashboard'un içinde çağrılıyor.
// import 'screens/signup_screen.dart'; <-- SARI ÇİZGİ SEBEBİ BUYDU, SİLDİK.
import 'screens/main_dashboard.dart'; // ✅ ANA KASAMIZ

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase başlatma
  await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
  );

  await ApiConfigService.instance.initialize();
  await ReminderNotificationService.instance.initialize();

  runApp(DirimApp());
}

class DirimApp extends StatelessWidget {
  const DirimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppBranding.appName,
      theme: ThemeData(
        primarySwatch: Colors.green,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E7A4C)),
        useMaterial3: true,
      ),
      // Akıllı Auth Kontrolü
      home: AuthWidget(),
    );
  }
}

// Bu widget, giriş durumuna göre sayfayı değiştirir
class AuthWidget extends StatelessWidget {
  const AuthWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Yükleniyor durumu (bağlantı kurulurken boş ekran yerine loading gösterebilirsin)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Eğer session varsa ana sayfaya git
        if (snapshot.hasData && snapshot.data!.session != null) {
          // ✅ ARTIK DİREKT ANA KASAYA (DASHBOARD) GİDİYORUZ
          return MainDashboard();
        }

        // Session yoksa giriş ekranına git
        return LoginScreen();
      },
    );
  }
}
