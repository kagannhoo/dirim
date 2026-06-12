import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../constants/colors.dart';
import '../services/api_config_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _config = ApiConfigService.instance;
  final _espController = TextEditingController();
  final _aiController = TextEditingController();
  bool _saving = false;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _espController.text = _config.espHost;
    _aiController.text = _config.aiServerBase;
  }

  @override
  void dispose() {
    _espController.dispose();
    _aiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _testMessage = null;
    });

    try {
      await _config.saveEspHost(_espController.text);
      await _config.saveAiServerBase(_aiController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bağlantı ayarları kaydedildi'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testEsp() async {
    setState(() => _testMessage = 'ESP test ediliyor...');
    try {
      final response = await http
          .get(_config.espVitalsUri)
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _testMessage = 'ESP bağlantısı OK — durum: ${data['status']}');
      } else {
        setState(() => _testMessage = 'ESP yanıt kodu: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _testMessage = 'ESP erişilemedi: $e');
    }
  }

  Future<void> _testAi() async {
    setState(() => _testMessage = 'AI sunucusu test ediliyor...');
    try {
      final healthUri = Uri.parse('${_config.aiServerBase}/docs');
      final response = await http
          .get(healthUri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        setState(() => _testMessage = 'AI sunucusu erişilebilir (/docs açıldı)');
      } else {
        setState(() => _testMessage = 'AI sunucusu yanıt kodu: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _testMessage = 'AI sunucusu erişilemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.textDarkGrey,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _hotspotDemoCard(),
          const SizedBox(height: 16),
          _infoCard(),
          const SizedBox(height: 20),
          Text(
            'Cihaz bağlantıları',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDarkGrey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'IP değiştiğinde buradan güncelleyin; uygulamayı yeniden derlemenize gerek kalmaz.',
            style: TextStyle(fontSize: 13, color: AppColors.textLightGrey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _espController,
            decoration: const InputDecoration(
              labelText: 'ESP32 adresi',
              hintText: '192.168.1.100 veya dirim-esp.local',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppColors.surfaceWhite,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _aiController,
            decoration: const InputDecoration(
              labelText: 'AI sunucusu (Python)',
              hintText: 'http://192.168.1.100:8001 veya https://api.sizin-domain.com',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppColors.surfaceWhite,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testEsp,
                  icon: const Icon(Icons.sensors),
                  label: const Text('ESP test'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testAi,
                  icon: const Icon(Icons.psychology_outlined),
                  label: const Text('AI test'),
                ),
              ),
            ],
          ),
          if (_testMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _testMessage!,
              style: TextStyle(fontSize: 13, color: AppColors.textLightGrey),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }

  void _applyHotspotPreset() {
    setState(() {
      _espController.text = '192.168.43.124';
      _aiController.text = 'http://192.168.43.136:8000';
      _testMessage =
          'Hotspot şablonu yüklendi. PC ve ESP\'ye aynı sabit IP\'leri ver, Kaydet + test yap.';
    });
  }

  Widget _hotspotDemoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.wifi_tethering, color: Colors.orange, size: 22),
              SizedBox(width: 8),
              Text(
                'Hızlı demo — telefon hotspot',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Telefon hotspot\'u sabit IP atamaz; sabit IP\'yi ESP ve bilgisayarda sen verirsin. '
            'Android hotspot ağı genelde 192.168.43.x',
            style: TextStyle(fontSize: 13, color: AppColors.textLightGrey, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Önerilen:\n'
            '• ESP → 192.168.43.124\n'
            '• Bilgisayar (Python) → 192.168.43.136\n'
            '• Ağ geçidi → 192.168.43.1',
            style: TextStyle(fontSize: 13, color: AppColors.textDarkGrey, height: 1.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _applyHotspotPreset,
              child: const Text('Hotspot IP şablonunu yükle'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'IP sorunu için öneriler',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDarkGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _bullet('Hotspot: telefon sadece internet dağıtır; sabit IP ESP + PC tarafında'),
          _bullet('Kube/VRA: ödev sonrası; AI sunucusu veritabanı gerektirmez (stateless)'),
          _bullet('ESP→Supabase: canlı veri olur ama ~1-2 sn gecikme; bugünkü demo için ESP\'ye direkt bağlan'),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: AppColors.textLightGrey)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: AppColors.textLightGrey, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
