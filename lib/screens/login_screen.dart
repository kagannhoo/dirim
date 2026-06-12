import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_branding.dart';
import '../constants/colors.dart';
import '../widgets/dirim_logo.dart';
import 'signup_screen.dart';
// import 'home_screen.dart'; <-- SİLDİK (Gereksizdi)
// import 'screens/main_dashboard.dart'; <-- SİLDİK (Gereksizdi, çünkü AuthWidget bizi yönlendirecek)

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _isLoading = false; // Yüklenme efekti için ekledik

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Butona basılınca dönmeye başlasın
      });

      try {
        await _supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // ✅ ÖNEMLİ DEĞİŞİKLİK BURADA:
        // Eskiden burada Navigator.pushReplacement ile manuel olarak MainDashboard'a gitmeye çalışıyordun.
        // O kısmı TAMAMEN SİLDİK. Neden?
        // Çünkü main.dart içindeki "AuthWidget" zaten giriş yapıldığını hissettiği an seni otomatik olarak MainDashboard'a uçuracak.
      } on AuthException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Giriş hatası: ${error.message}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Beklenmedik bir hata oluştu!"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false; // İşlem bitince dönmeyi durdur
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DirimLogo(size: 100),
                SizedBox(height: 16),
                Text(
                  "${AppBranding.appName}'e Hoş Geldin",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDarkGrey,
                  ),
                ),
                SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration("E-posta", Icons.email),
                  validator: (value) =>
                      value!.contains('@') ? null : 'Geçerli e-posta giriniz',
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _inputDecoration("Şifre", Icons.lock),
                  validator: (value) =>
                      value!.length >= 6 ? null : 'En az 6 karakter',
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : _login, // Yüklenirken butonu deaktif et
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Giriş Yap",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignUpScreen()),
                  ),
                  child: Text(
                    "Hesabın yok mu? Kaydol",
                    style: TextStyle(color: AppColors.textLightGrey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.surfaceWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      prefixIcon: Icon(icon, color: AppColors.primaryBlue),
    );
  }
}
