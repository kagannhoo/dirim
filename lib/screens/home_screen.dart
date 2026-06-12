import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sensor_detail_screen.dart';
import 'face_analysis_screen.dart';
import '../constants/colors.dart';
import '../services/api_config_service.dart';
// Bu satırı home_screen.dart'taki import listesinin en altına ekle:
import 'health_summary_screen.dart';
import 'my_medications_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- Canlı Veri Değişkenleri (Mini Kartlar İçin) ---
  String _bpmValue = "--";
  String _spo2Value = "--";
  String _stresStatus = "Hesaplanıyor...";
  String _tempValue = "36.5";

  // --- Dinamik Günlük Skor Değişkenleri (Ana Kart İçin) ---
  int _healthScore = 100;
  String _healthStatus = "Veriler Çekiliyor...";
  String _healthDescription =
      "Veritabanındaki bugünün tüm ölçümleri analiz ediliyor.";

  Timer? _vitalsTimer;
  Timer? _saveTimer;
  int _fetchCount = 0;

  final _config = ApiConfigService.instance;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    // Supabase ve diğer bağlantıların tam olarak hazır olduğundan emin olmak için
    // render döngüsünün bitmesini bekliyoruz. Bu, "context" hatası almanı engeller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateDailyHealthMetrics();
      _fetchLiveVitals();
    });

    // 1.5 saniyede bir canlı veriyi çekip sadece ALT mini kartları günceller
    _vitalsTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      _fetchLiveVitals();
    });

    // 10 saniyede bir Supabase'e kaydet ve ana skoru yenile
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _saveSensorDataToSupabase();
    });
  }

  @override
  void dispose() {
    _vitalsTimer?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  // ---  AKILLI GÜNLÜK SKOR VE STRES ALGORİTMASI ---
  Future<void> _calculateDailyHealthMetrics() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String();

      // 1. Veritabanından Bugünün Tüm Verilerini Çek
      final faceResponse = await _supabase
          .from('health_history')
          .select('stress_score')
          .eq('user_id', user.id)
          .gte('created_at', startOfDay);
      final bpmResponse = await _supabase
          .from('sensor_history')
          .select('value')
          .eq('user_id', user.id)
          .eq('sensor_type', 'nabiz')
          .gte('created_at', startOfDay);
      final spo2Response = await _supabase
          .from('sensor_history')
          .select('value')
          .eq('user_id', user.id)
          .eq('sensor_type', 'spo2')
          .gte('created_at', startOfDay);

      // 2. Ortalamaları Hesapla
      double avgFaceStress = 0.0;
      if (faceResponse.isNotEmpty) {
        double total = 0;
        for (var row in faceResponse)
          total += (row['stress_score'] as num).toDouble();
        avgFaceStress = total / faceResponse.length;
      }

      double avgBpm = 0.0;
      if (bpmResponse.isNotEmpty) {
        double total = 0;
        for (var row in bpmResponse) total += (row['value'] as num).toDouble();
        avgBpm = total / bpmResponse.length;
      }

      double avgSpo2 = 0.0;
      if (spo2Response.isNotEmpty) {
        double total = 0;
        for (var row in spo2Response) total += (row['value'] as num).toDouble();
        avgSpo2 = total / spo2Response.length;
      }
      // --- TAM BURAYA EKLE ---
      debugPrint("DEBUG: BPM Ortalaması: $avgBpm");
      debugPrint("DEBUG: SpO2 Ortalaması: $avgSpo2");
      debugPrint("DEBUG: Yüz Stres Ortalaması: $avgFaceStress");
      // -------------------------

      // 3. Stres Skoru Harmanlaması (%70 Yüz + %30 Nabız)
      double bpmStressFactor = 0.0;
      if (avgBpm > 85.0) {
        bpmStressFactor = (avgBpm - 85.0) * 1.5;
        if (bpmStressFactor > 100) bpmStressFactor = 100;
      }
      double combinedStress = (avgFaceStress * 0.70) + (bpmStressFactor * 0.30);

      String stressText = "Düşük";
      if (combinedStress >= 70)
        stressText = "Kritik";
      else if (combinedStress >= 50)
        stressText = "Yüksek";
      else if (combinedStress >= 30)
        stressText = "Orta";

      // 4. ANA SAĞLIK SKORU CEZA (DEDUCTION) SİSTEMİ (100 Üzerinden)
      int score = 100;

      if (avgSpo2 > 0) {
        if (avgSpo2 < 90)
          score -= 30;
        else if (avgSpo2 < 95)
          score -= 10;
      }

      if (avgBpm > 0) {
        if (avgBpm > 100)
          score -= 20;
        else if (avgBpm > 85)
          score -= 10;
        else if (avgBpm < 50)
          score -= 15;
      }

      if (combinedStress >= 70)
        score -= 20;
      else if (combinedStress >= 50)
        score -= 10;

      if (score < 0) score = 0;

      // 5. Durum Metinleri Ataması
      String status = "Veri Bekleniyor";
      String desc = "Yeterli ölçüm yok. Lütfen parmağınızı sensöre koyun.";

      if (avgBpm > 0 || avgSpo2 > 0) {
        if (score >= 85) {
          status = "Genel Durum: Mükemmel! 🚀";
          desc =
              "Günlük yaşamsal verileriniz ve zihinsel stabilite endeksiniz harika durumda.";
        } else if (score >= 70) {
          status = "Genel Durum: Hassas / Stabil ⚠️";
          desc =
              "Günlük ortalamanızda hafif bir stres veya yorgunluk belirtisi var. Dinlenmeye özen gösterin.";
        } else {
          status = "Genel Durum: Riskli / Dikkat! 🚨";
          desc =
              "Bugünkü genel değerleriniz alarm seviyesinde. Lütfen fiziksel aktiviteyi azaltın ve gözlemleyin.";
        }
      }

      // 6. UI Güncellemesi
      if (mounted) {
        setState(() {
          _stresStatus = "$stressText (%${combinedStress.toInt()})";
          _healthScore = score;
          _healthStatus = status;
          _healthDescription = desc;
        });
      }
    } catch (e) {
      debugPrint("Akıllı metrik hesaplama hatası: $e");
    }
  }

  Future<void> _fetchLiveVitals() async {
    final url = _config.espVitalsUri;
    try {
      final response = await http
          .get(url)
          .timeout(const Duration(milliseconds: 1000));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (mounted) {
          setState(() {
            if (data['status'] == 'no_finger') {
              _bpmValue = "0";
              _spo2Value = "0";
            } else {
              _bpmValue = data['bpm'].toString();
              _spo2Value = data['spo2'].toString();
            }
          });
        }
      }
    } catch (e) {
      debugPrint("ESP32 Canlı veri çekme hatası: $e");
    }
  }

  Future<void> _saveSensorDataToSupabase() async {
    final bpm = double.tryParse(_bpmValue) ?? 0;
    final spo2 = double.tryParse(_spo2Value) ?? 0;
    if (bpm <= 0 || spo2 <= 0) return;

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('sensor_history').insert({
        'user_id': user.id,
        'sensor_type': 'nabiz',
        'value': bpm,
        'created_at': DateTime.now().toIso8601String(),
      });

      await _supabase.from('sensor_history').insert({
        'user_id': user.id,
        'sensor_type': 'spo2',
        'value': spo2,
        'created_at': DateTime.now().toIso8601String(),
      });

      _calculateDailyHealthMetrics();
    } catch (e) {
      debugPrint("❌ Supabase sensör kayıt hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hoş geldin, Kağan 👋",
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.textLightGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 24),
              _buildMainHealthScoreCard(),
              SizedBox(height: 16),
              _buildFaceAnalysisCard(context),
              SizedBox(height: 16),
              _buildMedicationsQuickCard(context),
              SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85, // DÜZELTME: Kutular artık daha uzun
                children: [
                  _buildMiniSensorCard(
                    context,
                    "Nabız",
                    _bpmValue,
                    "BPM",
                    Icons.favorite,
                    AppColors.errorRed,
                    "nabiz",
                  ),
                  _buildMiniSensorCard(
                    context,
                    "SpO2",
                    _spo2Value,
                    "%",
                    Icons.water_drop,
                    AppColors.primaryBlue,
                    "spo2",
                  ),
                  _buildMiniSensorCard(
                    context,
                    "Sıcaklık",
                    _tempValue,
                    "°C",
                    Icons.thermostat,
                    Colors.orange,
                    "sicaklik",
                  ),
                  _buildMiniSensorCard(
                    context,
                    "Stres",
                    _stresStatus,
                    "",
                    Icons.self_improvement,
                    Colors.green,
                    "stres",
                  ),
                ],
              ),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainHealthScoreCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HealthSummaryScreen(
              score: _healthScore,
              status: _healthStatus,
              description: _healthDescription,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: _healthScore / 100,
                    strokeWidth: 10,
                    backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _healthScore < 70
                          ? AppColors.errorRed
                          : AppColors.primaryBlue,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "$_healthScore",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDarkGrey,
                          ),
                        ),
                        Text(
                          "/100",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textLightGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _healthStatus,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDarkGrey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _healthDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textLightGrey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationsQuickCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MyMedicationsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.medication_liquid, color: Color(0xFF6C5CE7), size: 28),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'İlaçlarım',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDarkGrey,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '75+ ilaç kataloğu · hatırlatıcı entegrasyonu',
                    style: TextStyle(fontSize: 12, color: AppColors.textLightGrey),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceAnalysisCard(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FaceAnalysisScreen(
              currentBpm: _bpmValue,
              currentSpo2: _spo2Value,
            ),
          ),
        );
        if (result != null && context.mounted) {
          _calculateDailyHealthMetrics();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: EdgeInsets.only(bottom: 20, left: 16, right: 16),
              elevation: 4,
            ),
          );
        }
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryBlue, Color(0xFF4A90E2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.face_retouching_natural,
                color: Colors.white,
                size: 32,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Yüz Analizi",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Kamera ile anlık sağlık taraması",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniSensorCard(
    BuildContext context,
    String title,
    String val,
    String unit,
    IconData icon,
    Color iconColor,
    String type,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SensorDetailScreen(sensorType: type),
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: iconColor, size: 28),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textLightGrey,
                  size: 20,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textLightGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                // DÜZELTME: FittedBox EKLENDİ - Yazı uzunsa otomatik küçülür
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        val,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDarkGrey,
                        ),
                      ),
                      SizedBox(width: 2),
                      Text(
                        unit,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLightGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
