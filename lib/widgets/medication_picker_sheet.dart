import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/medication.dart';
import '../services/medication_service.dart';
import '../screens/my_medications_screen.dart';
import 'medication_detail_card.dart';

class MedicationPickerSheet extends StatefulWidget {
  const MedicationPickerSheet({super.key});

  static Future<UserMedication?> pick(BuildContext context) {
    return showModalBottomSheet<UserMedication>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MedicationPickerSheet(),
    );
  }

  @override
  State<MedicationPickerSheet> createState() => _MedicationPickerSheetState();
}

class _MedicationPickerSheetState extends State<MedicationPickerSheet> {
  List<UserMedication> _myMeds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final meds = await MedicationService.instance.fetchMyMedications();
    if (mounted) setState(() { _myMeds = meds; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 48),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'İlaçlarımdan Seç',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MyMedicationsScreen()));
                  },
                  child: const Text('İlaçlarım'),
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primaryBlue))
          else if (_myMeds.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('Henüz ilaç eklemediniz', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyMedicationsScreen()));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                    child: const Text('İlaçlarım sayfasına git', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _myMeds.length,
                itemBuilder: (context, i) {
                  final um = _myMeds[i];
                  return MedicationDetailCard(
                    medication: um.medication,
                    trailing: FilledButton(
                      onPressed: () => Navigator.pop(context, um),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                      child: const Text('Seç', style: TextStyle(color: Colors.white)),
                    ),
                    onTap: () => Navigator.pop(context, um),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
