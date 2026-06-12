import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../widgets/dirim_logo.dart';
import 'login_screen.dart'; // Giriş ekranına yönlendirebilmek için import et

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedGender;
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;

  Future<void> _signUp() async {
    if (_isLoading) return;

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // 1. Auth kaydı
        final AuthResponse res = await _supabase.auth.signUp(
          email: _emailController.text,
          password: _passwordController.text,
        );

        // 2. Profil tablosuna ekleme (users_profile — hesap bilgileri sayfasıyla uyumlu)
        if (res.user != null) {
          await _supabase.from('users_profile').upsert({
            'user_id': res.user!.id,
            'email': _emailController.text.trim(),
            'full_name': _nameController.text.trim(),
            'age': int.tryParse(_ageController.text) ?? 0,
            'gender': _selectedGender,
            'updated_at': DateTime.now().toIso8601String(),
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Kayıt başarılı! Şimdi giriş yapabilirsiniz."),
              ),
            );

            // 3. Giriş ekranına yönlendir
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LoginScreen()),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Hata: ${e.toString()}")));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: BackButton(color: AppColors.textDarkGrey),
                ),
                const Center(child: DirimLogo(size: 72)),
                SizedBox(height: 12),
                Text(
                  "Hesap Oluştur",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDarkGrey,
                  ),
                ),
                SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration("Ad Soyad", Icons.person),
                  validator: (value) =>
                      value!.isEmpty ? 'Ad Soyad gerekli' : null,
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          "Yaş",
                          Icons.calendar_today,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: _inputDecoration("Cinsiyet", Icons.wc),
                        value: _selectedGender,
                        isExpanded: true,
                        items: ['Erkek', 'Kadın', 'Diğer']
                            .map(
                              (label) => DropdownMenuItem(
                                child: Text(label),
                                value: label,
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedGender = value),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
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
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Kaydol",
                          style: TextStyle(fontSize: 18, color: Colors.white),
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
