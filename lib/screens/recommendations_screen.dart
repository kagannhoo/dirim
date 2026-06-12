import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../services/api_config_service.dart';

class _SmartReminder {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? dataTag;

  const _SmartReminder({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.dataTag,
  });
}

class RecommendationsScreen extends StatefulWidget {
  @override
  _RecommendationsScreenState createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isAILoading = true;

  String _latestEmotion = "Bilinmiyor";
  String _latestStress = "Normal";
  String _latestFatigue = "Dinlenmiş";
  double _avgBpm = 0.0;
  double _avgSpo2 = 0.0;
  double _avgStressScore = 0.0;
  int _healthScore = 100;

  String _geminiAdvice = "";
  List<_SmartReminder> _smartReminders = [];

  final _config = ApiConfigService.instance;

  @override
  void initState() {
    super.initState();
    _fetchAndProcessDailyAverages();
  }

  Future<void> _fetchAndProcessDailyAverages() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

      final faceResponse = await _supabase
          .from('health_history')
          .select()
          .eq('user_id', user.id)
          .gte('created_at', startOfDay)
          .order('created_at', ascending: false);

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

      if (bpmResponse.isNotEmpty) {
        double total = 0;
        for (var row in bpmResponse) total += (row['value'] as num).toDouble();
        _avgBpm = total / bpmResponse.length;
      }

      if (spo2Response.isNotEmpty) {
        double total = 0;
        for (var row in spo2Response) total += (row['value'] as num).toDouble();
        _avgSpo2 = total / spo2Response.length;
      }

      if (faceResponse.isNotEmpty) {
        final lastRow = faceResponse.first;
        _latestEmotion = lastRow['emotion'] ?? "Bilinmiyor";
        _latestStress = lastRow['stress_score']?.toString() ?? "Normal";
        _latestFatigue = lastRow['fatigue'] ?? "Dinlenmiş";

        double stressTotal = 0;
        for (var row in faceResponse) {
          final val = row['stress_score'];
          if (val is num) stressTotal += val.toDouble();
        }
        _avgStressScore = stressTotal / faceResponse.length;
      }

      _healthScore = _calculateHealthScore();
      _smartReminders = _buildDataDrivenReminders();

      if (faceResponse.isNotEmpty || bpmResponse.isNotEmpty) {
        setState(() => _isLoading = false);

        _generateRealAIAdvice(
          bpm: _avgBpm > 0 ? _avgBpm.toInt().toString() : "75",
          spo2: _avgSpo2 > 0 ? _avgSpo2.toInt().toString() : "98",
          emotion: _latestEmotion,
          stress: _latestStress.contains('%') ? _latestStress : _latestStress,
          fatigue: _latestFatigue,
        );
      } else {
        setState(() {
          _isLoading = false;
          _isAILoading = false;
          _geminiAdvice =
              "Henüz bugün için yeterli sağlık veriniz bulunmuyor. Lütfen anasayfadan yüz analizi yapın ve sensörü kullanın.";
          _smartReminders = _buildDefaultReminders();
        });
      }
    } catch (e) {
      debugPrint("Öneriler veritabanı analizi hatası: $e");
      setState(() {
        _isLoading = false;
        _isAILoading = false;
        _geminiAdvice =
            "Veriler işlenirken bir hata oluştu. Lütfen internetinizi kontrol edin.";
        _smartReminders = _buildDefaultReminders();
      });
    }
  }

  int _calculateHealthScore() {
    int score = 100;
    if (_avgBpm > 100) score -= 15;
    else if (_avgBpm > 90) score -= 8;
    if (_avgSpo2 > 0 && _avgSpo2 < 95) score -= 20;
    else if (_avgSpo2 > 0 && _avgSpo2 < 97) score -= 10;
    if (_avgStressScore > 70) score -= 20;
    else if (_avgStressScore > 50) score -= 10;
    if (_latestFatigue.contains('Bitkin') || _latestFatigue.contains('Stresli')) {
      score -= 15;
    }
    return score.clamp(0, 100);
  }

  List<_SmartReminder> _buildDataDrivenReminders() {
    final reminders = <_SmartReminder>[];

    // Hidrasyon — her zaman
    reminders.add(_SmartReminder(
      title: "Hidrasyon Hatırlatıcısı",
      description: _avgBpm > 90
          ? "Nabzınız bugün ${_avgBpm.toInt()} bpm ile yükselmiş. Dehidrasyon nabzı artırabilir — günde 2.5–3 litre su hedefleyin."
          : "Sistemik sağlığınızı desteklemek için günde 2.5–3 litre su tüketmeyi ihmal etmeyin.",
      icon: Icons.water_drop,
      color: Colors.blue,
      dataTag: "Genel",
    ));

    // Uyku kalitesi — yorgunluk veya düşük skor
    if (_latestFatigue.contains('Bitkin') ||
        _latestFatigue.contains('Stresli') ||
        _latestFatigue.contains('Yorgun') ||
        _healthScore < 75) {
      reminders.add(_SmartReminder(
        title: "Uyku Kalitenizi Artırın",
        description: "Yorgunluk seviyeniz '${_latestFatigue}' olarak ölçüldü. Bu gece 22:00'den önce yatmayı, ekranları 1 saat önce kapatmayı ve 7–8 saat uyku hedefleyin.",
        icon: Icons.bedtime_outlined,
        color: const Color(0xFF5C6BC0),
        dataTag: "Yorgunluk verisi",
      ));
    }

    // Stres yönetimi
    if (_avgStressScore > 50 ||
        _latestStress.contains('Risk') ||
        _latestStress.contains('Yüksek') ||
        _latestEmotion == 'Korku' ||
        _latestEmotion == 'Üzgün') {
      reminders.add(_SmartReminder(
        title: "Stres Yönetimi Molası",
        description: _avgStressScore > 0
            ? "Stres skorunuz bugün ortalama %${_avgStressScore.toInt()} seviyesinde. 5 dakikalık derin nefes egzersizi (4-7-8 tekniği) veya kısa bir yürüyüş önerilir."
            : "Stres seviyeniz yükselmiş görünüyor. Günde 10 dakika meditasyon veya nefes egzersizi stresi %30'a kadar azaltabilir.",
        icon: Icons.self_improvement,
        color: Colors.teal,
        dataTag: "Stres analizi",
      ));
    }

    // Nabız / aktivite
    if (_avgBpm > 100) {
      reminders.add(_SmartReminder(
        title: "Dinlenme ve Nabız Kontrolü",
        description: "Ortalama nabzınız ${_avgBpm.toInt()} bpm — normal üst sınırın üzerinde. 15 dakika oturarak dinlenin, kafein tüketimini azaltın ve nabzınızı tekrar ölçün.",
        icon: Icons.favorite_outline,
        color: AppColors.errorRed,
        dataTag: "Nabız verisi",
      ));
    } else if (_avgBpm > 0 && _avgBpm < 60) {
      reminders.add(_SmartReminder(
        title: "Hafif Aktivite Önerisi",
        description: "Nabzınız ${_avgBpm.toInt()} bpm ile düşük seyrediyor. Günde 20 dakika tempolu yürüyüş kalp sağlığınızı destekler.",
        icon: Icons.directions_walk,
        color: Colors.orange,
        dataTag: "Nabız verisi",
      ));
    }

    // SpO2
    if (_avgSpo2 > 0 && _avgSpo2 < 97) {
      reminders.add(_SmartReminder(
        title: "Oksijen Seviyesi Takibi",
        description: "SpO2 ortalamanız %${_avgSpo2.toInt()} — ideal aralığın (%97–100) altında. Derin nefes egzersizleri yapın, iyi havalandırılmış ortamda kalın. %95'in altında doktora başvurun.",
        icon: Icons.air,
        color: const Color(0xFF00897B),
        dataTag: "SpO2 verisi",
      ));
    }

    // Duygu durumu
    if (_latestEmotion == 'Mutlu' || _latestEmotion == 'Sakin') {
      reminders.add(_SmartReminder(
        title: "Pozitif Ruh Halinizi Koruyun",
        description: "Bugünkü duygu durumunuz '${_latestEmotion}' — harika! Düzenli egzersiz ve sosyal bağlantılar bu pozitif durumu sürdürmenize yardımcı olur.",
        icon: Icons.emoji_emotions_outlined,
        color: Colors.amber.shade700,
        dataTag: "Duygu analizi",
      ));
    }

    // Genel sağlık skoru düşükse
    if (_healthScore < 60 && reminders.length < 5) {
      reminders.add(_SmartReminder(
        title: "Günlük Sağlık Kontrolü",
        description: "Sağlık skorunuz $_healthScore/100. Bugün yüz analizi tekrarlayın, sensör verilerinizi güncel tutun ve yeterli dinlenmeye öncelik verin.",
        icon: Icons.health_and_safety_outlined,
        color: Colors.deepPurple,
        dataTag: "Sağlık skoru",
      ));
    }

    // Minimum 4 hatırlatıcı garantisi
    if (reminders.length < 4) {
      final defaults = _buildDefaultReminders();
      for (final d in defaults) {
        if (reminders.length >= 5) break;
        if (!reminders.any((r) => r.title == d.title)) {
          reminders.add(d);
        }
      }
    }

    return reminders.take(5).toList();
  }

  List<_SmartReminder> _buildDefaultReminders() {
    return [
      const _SmartReminder(
        title: "Hidrasyon Hatırlatıcısı",
        description: "Günde 2.5–3 litre su tüketmeyi hedefleyin. Sabah kalktığınızda bir bardak su içmeyi alışkanlık haline getirin.",
        icon: Icons.water_drop,
        color: Colors.blue,
      ),
      const _SmartReminder(
        title: "Uyku Kalitenizi Artırın",
        description: "Her gece aynı saatte yatın, yatak odanızı karanlık ve serin tutun. 7–8 saat uyku bağışıklık sistemini güçlendirir.",
        icon: Icons.bedtime_outlined,
        color: Color(0xFF5C6BC0),
      ),
      const _SmartReminder(
        title: "Günlük Hareket Hedefi",
        description: "Günde en az 30 dakika orta tempolu aktivite (yürüyüş, merdiven) kalp-damar sağlığınızı korur.",
        icon: Icons.directions_walk,
        color: Colors.orange,
      ),
      const _SmartReminder(
        title: "Zihinsel Sağlık Molası",
        description: "Günde 10 dakika meditasyon veya nefes egzersizi stres hormonlarını düşürür ve odaklanmanızı artırır.",
        icon: Icons.self_improvement,
        color: Colors.teal,
      ),
    ];
  }

  Future<void> _generateRealAIAdvice({
    required String bpm,
    required String spo2,
    required String emotion,
    required String stress,
    required String fatigue,
  }) async {
    try {
      final url = _config.generateAiAdviceUri;

      final apiRes = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'bpm': bpm,
              'spo2': spo2,
              'emotion': emotion,
              'stress': stress,
              'fatigue': fatigue,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (apiRes.statusCode == 200) {
        final data = json.decode(apiRes.body);
        setState(() {
          _geminiAdvice = data['status'] == 'success'
              ? data['advice']
              : "Yapay zeka öneri oluşturamadı: ${data['message']}";
          _isAILoading = false;
        });
      } else {
        setState(() {
          _geminiAdvice = "Sunucu Hatası: ${apiRes.statusCode}";
          _isAILoading = false;
        });
      }
    } catch (e) {
      debugPrint("Yapay zeka motoru bağlantı hatası: $e");
      setState(() {
        _geminiAdvice =
            "Python sunucusuna bağlanılamadı. IP adresin doğru mu ve Python terminali açık mı?";
        _isAILoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchAndProcessDailyAverages,
          color: AppColors.primaryBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryBlue, Colors.blue.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Dirim AI Önerileri",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Bugünkü ortalamalarınıza göre kişiselleştirilmiş aksiyon planınız.",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  "Günlük Aksiyon Planınız",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDarkGrey,
                  ),
                ),
                const SizedBox(height: 16),

                if (_isAILoading)
                  _buildLoadingCard()
                else
                  _buildRecommendationCard(
                    title: "AI Koçunuzun Tavsiyesi",
                    description: _geminiAdvice,
                    icon: Icons.psychology_alt,
                    color: Colors.teal,
                  ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Veriye Dayalı Hatırlatmalar",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDarkGrey,
                        ),
                      ),
                    ),
                    if (_avgBpm > 0 || _avgSpo2 > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Skor: $_healthScore",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Sensör ve yüz analizi verilerinize göre oluşturuldu",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),

                ..._smartReminders.map(
                  (r) => _buildRecommendationCard(
                    title: r.title,
                    description: r.description,
                    icon: r.icon,
                    color: r.color,
                    dataTag: r.dataTag,
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    String? dataTag,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDarkGrey,
                          ),
                        ),
                      ),
                      if (dataTag != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            dataTag,
                            style: TextStyle(fontSize: 10, color: color),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.5,
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

  Widget _buildLoadingCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: Colors.teal),
              SizedBox(height: 16),
              Text(
                "Bugünkü biyometrik ortalamalarınız analiz ediliyor...",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
