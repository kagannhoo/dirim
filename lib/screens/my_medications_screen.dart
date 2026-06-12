import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/medication.dart';
import '../services/medication_service.dart';
import '../widgets/medication_detail_card.dart';
import 'reminders_screen.dart';

class MyMedicationsScreen extends StatefulWidget {
  const MyMedicationsScreen({super.key});

  @override
  State<MyMedicationsScreen> createState() => _MyMedicationsScreenState();
}

class _MyMedicationsScreenState extends State<MyMedicationsScreen> with SingleTickerProviderStateMixin {
  final _service = MedicationService.instance;
  late TabController _tabController;

  List<UserMedication> _myMeds = [];
  List<Medication> _catalog = [];
  List<String> _categories = [];
  String? _selectedCategory;
  String _search = '';
  final _searchCtrl = TextEditingController();
  bool _loadingMy = true;
  bool _loadingCatalog = true;
  final Set<String> _addedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadMyMeds(), _loadCatalog()]);
  }

  Future<void> _loadMyMeds() async {
    setState(() => _loadingMy = true);
    final meds = await _service.fetchMyMedications();
    if (mounted) {
      setState(() {
        _myMeds = meds;
        _addedIds
          ..clear()
          ..addAll(meds.map((m) => m.medicationId));
        _loadingMy = false;
      });
    }
  }

  Future<void> _loadCatalog() async {
    setState(() => _loadingCatalog = true);
    final cats = await _service.fetchCategories();
    final meds = await _service.fetchCatalog(
      category: _selectedCategory,
      search: _search,
    );
    if (mounted) {
      setState(() {
        _categories = cats;
        _catalog = meds;
        _loadingCatalog = false;
      });
    }
  }

  Future<void> _showAddDialog(Medication med) async {
    if (_addedIds.contains(med.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu ilaç zaten İlaçlarım listesinde'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    String? frequency = kMedicationFrequencies.first;
    final dosageCtrl = TextEditingController(text: med.name);
    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${med.name} ekle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dosageCtrl,
                decoration: const InputDecoration(labelText: 'Doz / Kullanım'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: frequency,
                decoration: const InputDecoration(labelText: 'Sıklık'),
                items: kMedicationFrequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) => frequency = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Not (opsiyonel)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ekle', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _service.addToMyMedications(
        medicationId: med.id,
        customDosage: dosageCtrl.text.trim(),
        frequency: frequency,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
      await _loadMyMeds();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${med.name} İlaçlarım\'a eklendi'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _removeUserMed(UserMedication um) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İlaçı Kaldır'),
        content: Text('${um.medication.name} İlaçlarım listesinden kaldırılsın mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaldır', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.removeFromMyMedications(um.id);
    await _loadMyMeds();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        title: const Text('İlaçlarım', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'İlaçlarım (${_myMeds.length})'),
            const Tab(text: 'İlaç Kataloğu'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMyTab(), _buildCatalogTab()],
      ),
    );
  }

  Widget _buildMyTab() {
    if (_loadingMy) {
      return Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
    }
    if (_myMeds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.medication_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('Henüz ilaç eklemediniz', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'İlaç Kataloğu sekmesinden ilaç seçip İlaçlarım\'a ekleyin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _tabController.animateTo(1),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                child: const Text('Kataloğa Git', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyMeds,
      color: AppColors.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myMeds.length,
        itemBuilder: (context, i) {
          final um = _myMeds[i];
          return Column(
            children: [
              MedicationDetailCard(medication: um.medication),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (um.customDosage != null && um.customDosage!.isNotEmpty)
                      Text('Doz: ${um.customDosage}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (um.frequency != null) Text('Sıklık: ${um.frequency}', style: TextStyle(color: Colors.grey.shade700)),
                    if (um.notes != null && um.notes!.isNotEmpty)
                      Text('Not: ${um.notes}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RemindersScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.alarm_add, size: 18),
                            label: const Text('Hatırlatıcı'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _removeUserMed(um),
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCatalogTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'İlaç, etken madde veya sağlık sorunu ara...',
              prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _loadCatalog(),
            onChanged: (v) {
              _search = v;
              if (v.isEmpty) _loadCatalog();
            },
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: const Text('Tümü'),
                  selected: _selectedCategory == null,
                  onSelected: (_) {
                    setState(() => _selectedCategory = null);
                    _loadCatalog();
                  },
                ),
              ),
              ..._categories.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(c, style: const TextStyle(fontSize: 12)),
                      selected: _selectedCategory == c,
                      onSelected: (_) {
                        setState(() => _selectedCategory = c);
                        _loadCatalog();
                      },
                    ),
                  )),
            ],
          ),
        ),
        Expanded(
          child: _loadingCatalog
              ? Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
              : _catalog.isEmpty
                  ? const Center(child: Text('Sonuç bulunamadı'))
                  : RefreshIndicator(
                      onRefresh: _loadCatalog,
                      color: AppColors.primaryBlue,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _catalog.length,
                        itemBuilder: (context, i) {
                          final med = _catalog[i];
                          final added = _addedIds.contains(med.id);
                          return MedicationDetailCard(
                            medication: med,
                            trailing: added
                                ? Icon(Icons.check_circle, color: Colors.green.shade600)
                                : FilledButton(
                                    onPressed: () => _showAddDialog(med),
                                    style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                                    child: const Text('Ekle', style: TextStyle(color: Colors.white)),
                                  ),
                            onTap: () => _showAddDialog(med),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
