import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_secrets.dart';

/// Cihaz ve sunucu adreslerini tek yerden yönetir.
/// Önce yerel ayarlar, ardından Supabase'deki global AI URL okunur.
class ApiConfigService {
  ApiConfigService._();
  static final ApiConfigService instance = ApiConfigService._();

  static const _keyEspHost = 'esp_host';
  static const _keyAiServerBase = 'ai_server_base';

  static const String defaultEspHost = AppSecrets.defaultEspHost;
  static const String defaultAiServerBase = AppSecrets.defaultAiServerBase;

  String _espHost = defaultEspHost;
  String _aiServerBase = defaultAiServerBase;

  String get espHost => _espHost;
  String get aiServerBase => _aiServerBase;

  Uri get espVitalsUri => Uri.parse('http://$_espHost/api/vitals');
  Uri get analyzeFaceUri => Uri.parse('$_aiServerBase/analyze-face');
  Uri get generateAiAdviceUri => Uri.parse('$_aiServerBase/generate-ai-advice');

  final ValueNotifier<int> revision = ValueNotifier(0);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _espHost = prefs.getString(_keyEspHost) ??
        (defaultEspHost.isNotEmpty ? defaultEspHost : '192.168.1.100');
    final hasLocalAi = prefs.containsKey(_keyAiServerBase);
    final savedAi = prefs.getString(_keyAiServerBase);
    _aiServerBase = savedAi ??
        (defaultAiServerBase.isNotEmpty
            ? defaultAiServerBase
            : 'http://localhost:8001');
    // Telefonda kaydedilmiş adres varsa Supabase üzerine yazmasın (hotspot demo için).
    if (!hasLocalAi) {
      await _syncAiServerFromSupabase();
    }
  }

  Future<void> _syncAiServerFromSupabase() async {
    try {
      final row = await Supabase.instance.client
          .from('app_settings')
          .select('ai_server_url')
          .eq('id', 'global')
          .maybeSingle();

      final remote = row?['ai_server_url'] as String?;
      if (remote != null && remote.trim().isNotEmpty) {
        _aiServerBase = _normalizeBaseUrl(remote.trim());
        revision.value++;
      }
    } catch (e) {
      debugPrint('Supabase app_settings okunamadı (tablo yoksa normal): $e');
    }
  }

  Future<void> saveEspHost(String host) async {
    final normalized = _normalizeHost(host);
    _espHost = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEspHost, normalized);
    revision.value++;
  }

  Future<void> saveAiServerBase(String baseUrl) async {
    final normalized = _normalizeBaseUrl(baseUrl);
    _aiServerBase = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiServerBase, normalized);
    revision.value++;
  }

  Future<void> refreshFromSupabase() => _syncAiServerFromSupabase();

  String _normalizeHost(String input) {
    var value = input.trim();
    if (value.startsWith('http://')) value = value.substring(7);
    if (value.startsWith('https://')) value = value.substring(8);
    final slash = value.indexOf('/');
    if (slash != -1) value = value.substring(0, slash);
    return value;
  }

  String _normalizeBaseUrl(String input) {
    var value = input.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    return value;
  }
}
