import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_branding.dart';
import '../constants/colors.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'recommendations_screen.dart';
import 'reminders_screen.dart';
import 'reports_history_screen.dart';
import 'my_medications_screen.dart';
import 'settings_screen.dart';
import '../services/reminder_notification_service.dart';

class MainDashboard extends StatefulWidget {
  @override
  _MainDashboardState createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _selectedIndex = 0;
  final supabase = Supabase.instance.client;
  final _reportsKey = GlobalKey<ReportsHistoryScreenState>();

  String _displayName = 'Profiliniz';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _syncReminderNotifications();
  }

  Future<void> _syncReminderNotifications() async {
    await ReminderNotificationService.instance.requestPermissions();
    await ReminderNotificationService.instance.syncFromSupabase();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('users_profile')
          .select('full_name')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null && response['full_name'] != null) {
        setState(() {
          _displayName = response['full_name'];
        });
        return;
      }

      // Eski profiles tablosundan fallback
      try {
        final legacy = await supabase
            .from('profiles')
            .select('ad_soyad')
            .eq('auth_id', user.id)
            .maybeSingle();
        if (legacy != null && legacy['ad_soyad'] != null) {
          setState(() {
            _displayName = legacy['ad_soyad'];
          });
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Profil adı yüklenemedi: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 2) {
      _reportsKey.currentState?.refresh();
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        title: Text(
          _selectedIndex == 0
              ? AppBranding.appName
              : _selectedIndex == 1
                  ? "Öneriler"
                  : "Raporlarım",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primaryBlue),
              accountName: Text(
                _displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                supabase.auth.currentUser?.email ?? "Email bulunamadı",
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  _displayName.isNotEmpty && _displayName != 'Profiliniz'
                      ? _displayName.trim()[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.textDarkGrey),
              title: const Text("Hesap Bilgilerim"),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
                _loadUserProfile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: AppColors.textDarkGrey),
              title: const Text("Geçmiş Raporlarım"),
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.medication_liquid, color: AppColors.textDarkGrey),
              title: const Text("İlaçlarım"),
              subtitle: const Text("Katalog ve kişisel ilaç listesi", style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyMedicationsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined, color: AppColors.textDarkGrey),
              title: const Text("Sağlık Hatırlatıcıları"),
              subtitle: const Text("İlaç, randevu ve kontroller", style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RemindersScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings, color: AppColors.textDarkGrey),
              title: const Text("Ayarlar"),
              subtitle: const Text("ESP ve AI sunucu adresleri", style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Çıkış Yap", style: TextStyle(color: Colors.red)),
              onTap: _signOut,
            ),
          ],
        ),
      ),

      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(),
          RecommendationsScreen(),
          ReportsHistoryScreen(
            key: _reportsKey,
            isActive: _selectedIndex == 2,
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Anasayfa'),
          BottomNavigationBarItem(icon: Icon(Icons.self_improvement), label: 'Öneriler'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Raporlar'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }

}
