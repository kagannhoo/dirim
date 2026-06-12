import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/medication.dart';

class MedicationDetailCard extends StatelessWidget {
  final Medication medication;
  final Widget? trailing;
  final VoidCallback? onTap;

  const MedicationDetailCard({
    super.key,
    required this.medication,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: medication.prescriptionColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(medication.categoryIcon, color: medication.prescriptionColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDarkGrey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          medication.category,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 12),
              _infoRow(Icons.medical_information_outlined, 'Sağlık sorunu', medication.targetCondition),
              const SizedBox(height: 6),
              _infoRow(Icons.science_outlined, 'Etken madde', medication.activeIngredient),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: medication.prescriptionColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  medication.prescriptionType,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: medication.prescriptionColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
