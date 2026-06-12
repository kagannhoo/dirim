import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import 'face_analysis_screen.dart';

class ReportsHistoryScreen extends StatefulWidget {
  final bool isActive;

  const ReportsHistoryScreen({super.key, this.isActive = true});

  @override
  State<ReportsHistoryScreen> createState() => ReportsHistoryScreenState();
}

class ReportsHistoryScreenState extends State<ReportsHistoryScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void didUpdateWidget(ReportsHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadReports();
    }
  }

  Future<void> _loadReports() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('health_history')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _reports = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Raporlar yüklenemedi: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Veriler yüklenirken hata oluştu.';
      });
    }
  }

  Future<void> refresh() => _loadReports();

  Future<void> _deleteReport(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Raporu Sil', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Bu sağlık raporunu kalıcı olarak silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Optimistic UI: listeden hemen kaldır
    final backup = List<Map<String, dynamic>>.from(_reports);
    setState(() {
      _reports.removeWhere((r) => r['id'] == id);
    });

    try {
      await _supabase.from('health_history').delete().eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rapor başarıyla silindi.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _reports = backup);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Silme başarısız: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openReport(Map<String, dynamic> item) {
    final reconstructedData = {
      'clinical_analysis': {
        'psychological': {
          'dominant_emotion': item['emotion'] ?? 'Bilinmiyor',
          'stress_level': item['stress_score']?.toString() ?? 'Bilinmiyor',
          'fatigue_status': item['fatigue'] ?? 'Bilinmiyor',
          'ai_recommendation':
              item['ai_recommendation'] ?? 'Yapay zeka önerisi bulunmuyor.',
        },
        'neurological': {
          'facial_palsy_stroke_risk': item['facial_palsy'] ?? 'Bilinmiyor',
        },
        'ophthalmic': {
          'ptosis_eyelid_drop': item['ptosis'] ?? 'Bilinmiyor',
          'strabismus_eye_alignment': item['strabismus'] ?? 'Bilinmiyor',
          'sclera_jaundice': item['jaundice'] ?? 'Bilinmiyor',
          'conjunctivitis_redness': item['conjunctivitis'] ?? 'Bilinmiyor',
        },
        'systemic_dermatological': {
          'cyanosis_oxygen_deprivation': item['cyanosis'] ?? 'Bilinmiyor',
          'anemia_pallor_index': item['anemia'] ?? 'Bilinmiyor',
        },
      },
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceAnalysisResultScreen(
          aiData: reconstructedData,
          bpm: item['bpm']?.toString(),
          spo2: item['spo2']?.toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            TextButton(onPressed: _loadReports, child: const Text('Tekrar Dene')),
          ],
        ),
      );
    }

    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Henüz geçmiş bir analiziniz yok.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      color: AppColors.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final item = _reports[index];
          final date = DateTime.parse(item['created_at']).toLocal();
          final formattedDate =
              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} - '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

          final isRisk =
              item['stress_score'].toString().contains('Risk') ||
              item['fatigue'].toString().contains('Stresli') ||
              item['fatigue'].toString().contains('Bitkin');

          return Card(
            key: ValueKey(item['id']),
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openReport(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRisk
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    child: Icon(
                      isRisk ? Icons.warning_amber : Icons.check_circle,
                      color: isRisk ? Colors.red : Colors.green,
                    ),
                  ),
                  title: Text(
                    formattedDate,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textDarkGrey,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      'Duygu: ${item['emotion'] ?? '-'}\nYorgunluk: ${item['fatigue'] ?? '-'}',
                      style: const TextStyle(color: AppColors.textLightGrey, height: 1.3),
                    ),
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red.withValues(alpha: 0.7),
                      size: 28,
                    ),
                    onPressed: () => _deleteReport(item),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
