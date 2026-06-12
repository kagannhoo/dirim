import 'package:flutter/material.dart';
import '../constants/colors.dart';

class HealthSummaryScreen extends StatelessWidget {
  final int score;
  final String status;
  final String description;

  const HealthSummaryScreen({
    Key? key,
    required this.score,
    required this.status,
    required this.description,
  }) : super(key: key);

  // Skora göre renk
  Color get _scoreColor {
    if (score >= 85) return const Color(0xFF2ECC71); // yeşil
    if (score >= 70) return const Color(0xFFF39C12); // turuncu
    return const Color(0xFFE74C3C); // kırmızı
  }

  // Skora göre emoji
  String get _scoreEmoji {
    if (score >= 85) return "🟢";
    if (score >= 70) return "🟡";
    return "🔴";
  }

  // Skora göre kısa yorum
  String get _shortVerdict {
    if (score >= 85) return "Bugün harika görünüyorsun.";
    if (score >= 70) return "Biraz dikkat gerektiriyor.";
    return "Vücudun sana bir şeyler söylüyor.";
  }

  // Katkı kalemleri
  List<_ScoreItem> _buildItems() {
    return [
      _ScoreItem(
        icon: Icons.favorite_rounded,
        label: "Nabız",
        detail: "Normal aralıkta kalp ritmi",
        color: const Color(0xFFE74C3C),
      ),
      _ScoreItem(
        icon: Icons.water_drop_rounded,
        label: "SpO2",
        detail: "Kan oksijen doygunluğu",
        color: AppColors.primaryBlue,
      ),
      _ScoreItem(
        icon: Icons.self_improvement_rounded,
        label: "Stres",
        detail: "Yüz analizinden hesaplandı",
        color: const Color(0xFF9B59B6),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundWhite,
        elevation: 0,
        leading: BackButton(color: AppColors.textDarkGrey),
        title: Text(
          "Sağlık Özeti",
          style: TextStyle(
            color: AppColors.textDarkGrey,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- SKOR KARTI ---
            _buildScoreCard(),

            const SizedBox(height: 20),

            // --- DURUM AÇIKLAMASI ---
            _buildDescriptionCard(),

            const SizedBox(height: 20),

            // --- KATKI KALEMLERİ ---
            Text(
              "Skoru Etkileyen Faktörler",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textDarkGrey,
              ),
            ),
            const SizedBox(height: 12),
            ..._buildItems().map((item) => _buildScoreItemCard(item)),

            const SizedBox(height: 20),

            // --- BİLGİ NOTU ---
            _buildInfoNote(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Skor Kartı ──────────────────────────────────────────────
  Widget _buildScoreCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _scoreColor.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Dairesel gösterge
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 12,
                  backgroundColor: _scoreColor.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(_scoreColor),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "$score",
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDarkGrey,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        "/ 100",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textLightGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Durum etiketi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _scoreColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "$_scoreEmoji  $status",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _scoreColor,
              ),
            ),
          ),

          const SizedBox(height: 10),

          Text(
            _shortVerdict,
            style: TextStyle(fontSize: 13, color: AppColors.textLightGrey),
          ),
        ],
      ),
    );
  }

  // ── Açıklama Kartı ──────────────────────────────────────────
  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insights_rounded,
              color: AppColors.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textDarkGrey,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Faktör Kartı ────────────────────────────────────────────
  Widget _buildScoreItemCard(_ScoreItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDarkGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLightGrey,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textLightGrey,
            size: 20,
          ),
        ],
      ),
    );
  }

  // ── Bilgi Notu ───────────────────────────────────────────────
  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.textLightGrey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Puan; nabız, SpO2 ve stres verilerinin ağırlıklı ortalamasından otomatik hesaplanır.",
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textLightGrey,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Yardımcı veri sınıfı
class _ScoreItem {
  final IconData icon;
  final String label;
  final String detail;
  final Color color;

  const _ScoreItem({
    required this.icon,
    required this.label,
    required this.detail,
    required this.color,
  });
}
