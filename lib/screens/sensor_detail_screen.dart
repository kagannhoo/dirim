import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';

class SensorDetailScreen extends StatefulWidget {
  final String sensorType;

  const SensorDetailScreen({Key? key, required this.sensorType})
    : super(key: key);

  @override
  _SensorDetailScreenState createState() => _SensorDetailScreenState();
}

class _SensorDetailScreenState extends State<SensorDetailScreen> {
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  final _supabase = Supabase.instance.client;

  List<List<double>> _processedChartData = [];

  double _displayMin = 0;
  double _displayMax = 0;
  String _lastValue = "--";
  String _lastValueTime = "Veri yok";

  double get _getMinY {
    if (widget.sensorType == 'nabiz') return 40;
    if (widget.sensorType == 'spo2') return 80;
    return 34;
  }

  double get _getMaxY {
    if (widget.sensorType == 'nabiz') return 180;
    if (widget.sensorType == 'spo2') return 100;
    return 42;
  }

  Color get _sensorColor {
    switch (widget.sensorType) {
      case 'nabiz':
        return AppColors.errorRed;
      case 'spo2':
        return AppColors.primaryBlue;
      case 'sicaklik':
        return Colors.orange;
      default:
        return AppColors.textLightGrey;
    }
  }

  String get _sensorTitle {
    switch (widget.sensorType) {
      case 'nabiz':
        return 'Kalp Atış Hızı';
      case 'spo2':
        return 'Kandaki Oksijen';
      case 'sicaklik':
        return 'Vücut Sıcaklığı';
      default:
        return 'Detaylar';
    }
  }

  String get _sensorUnit {
    switch (widget.sensorType) {
      case 'nabiz':
        return 'bpm';
      case 'spo2':
        return '%';
      case 'sicaklik':
        return '°C';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAndProcessData();
  }

  Future<void> _fetchAndProcessData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);

      int intervalsCount;
      DateTime cutoffDate;

      if (_selectedTabIndex == 0) {
        intervalsCount = 7;
        cutoffDate = today.subtract(const Duration(days: 6));
      } else if (_selectedTabIndex == 1) {
        intervalsCount = 30;
        cutoffDate = today.subtract(const Duration(days: 29));
      } else {
        intervalsCount = 12;
        cutoffDate = DateTime(now.year, now.month - 11, 1);
      }

      final response = await _supabase
          .from('sensor_history')
          .select()
          .eq('user_id', user.id)
          .eq('sensor_type', widget.sensorType)
          .gte('created_at', cutoffDate.toIso8601String())
          .order('created_at', ascending: true);

      final List<dynamic> records = response as List<dynamic>;

      // Varsayılan değerler
      double defaultMin = widget.sensorType == 'nabiz'
          ? 70
          : (widget.sensorType == 'spo2' ? 97 : 36.5);
      double defaultMax = widget.sensorType == 'nabiz'
          ? 75
          : (widget.sensorType == 'spo2' ? 98 : 36.6);

      _processedChartData = List.generate(
        intervalsCount,
        (_) => [defaultMin, defaultMax],
      );

      if (records.isEmpty) {
        _lastValue = "--";
        _lastValueTime = "Veri bulunamadı";
        _displayMin = defaultMin;
        _displayMax = defaultMax;
        return;
      }

      // En son değeri üst karta yaz
      final lastRecord = records.last;
      _lastValue = lastRecord['value'].toString();
      final DateTime createTime = DateTime.parse(
        lastRecord['created_at'],
      ).toLocal();
      _lastValueTime =
          "En son ${createTime.hour}:${createTime.minute.toString().padLeft(2, '0')}";

      // Verileri gruplara ayır
      final Map<int, List<double>> groupedVals = {};

      for (var rec in records) {
        final DateTime recDate = DateTime.parse(rec['created_at']).toLocal();
        final double val = (rec['value'] as num).toDouble();
        int groupIndex;

        if (_selectedTabIndex == 0) {
          // 7 günlük: her gün bir sütun
          // today = index 6, yesterday = index 5, ...
          final DateTime recDay = DateTime(
            recDate.year,
            recDate.month,
            recDate.day,
          );
          final int dayDiff = today.difference(recDay).inDays;
          groupIndex = (intervalsCount - 1) - dayDiff;
        } else if (_selectedTabIndex == 1) {
          // 30 günlük: her gün bir sütun
          final DateTime recDay = DateTime(
            recDate.year,
            recDate.month,
            recDate.day,
          );
          final int dayDiff = today.difference(recDay).inDays;
          groupIndex = (intervalsCount - 1) - dayDiff;
        } else {
          // 12 aylık: her ay bir sütun
          // Bu ayın indexi = 11, bir önceki = 10, ...
          final int monthDiff =
              (now.year - recDate.year) * 12 + (now.month - recDate.month);
          groupIndex = (intervalsCount - 1) - monthDiff;
        }

        // Geçerli aralıkta mı kontrol et
        if (groupIndex >= 0 && groupIndex < intervalsCount) {
          groupedVals.putIfAbsent(groupIndex, () => []).add(val);
        }
      }

      // Gruplanan verilerden min/max hesapla
      double globalMin = double.infinity;
      double globalMax = double.negativeInfinity;

      groupedVals.forEach((index, values) {
        if (values.isNotEmpty) {
          final double min = values.reduce((a, b) => a < b ? a : b);
          final double max = values.reduce((a, b) => a > b ? a : b);
          _processedChartData[index] = [min, max];

          if (min < globalMin) globalMin = min;
          if (max > globalMax) globalMax = max;
        }
      });

      _displayMin = globalMin == double.infinity ? defaultMin : globalMin;
      _displayMax = globalMax == double.negativeInfinity
          ? defaultMax
          : globalMax;
    } catch (e) {
      debugPrint("Supabase geçmiş veri hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          _sensorTitle,
          style: TextStyle(
            color: AppColors.textDarkGrey,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: AppColors.textDarkGrey),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: AppColors.textDarkGrey),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _sensorColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildDailyRangeCard(),
                  const SizedBox(height: 24),
                  _buildTimeTabs(),
                  const SizedBox(height: 16),
                  _buildChartCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildDailyRangeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                widget.sensorType == 'sicaklik'
                    ? "${_displayMin.toStringAsFixed(1)} - ${_displayMax.toStringAsFixed(1)}"
                    : "${_displayMin.toInt()} - ${_displayMax.toInt()}",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDarkGrey,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _sensorUnit,
                style: TextStyle(fontSize: 16, color: AppColors.textLightGrey),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: _sensorColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              FractionallySizedBox(
                widthFactor: 0.75,
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: _sensorColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Son Değer: $_lastValue $_sensorUnit\n$_lastValueTime",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _sensorColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTabs() {
    return Row(
      children: [
        _buildTabButton("7 gün", 0),
        _buildTabButton("31 gün", 1),
        _buildTabButton("12 ay", 2),
      ],
    );
  }

  Widget _buildTabButton(String title, int index) {
    final bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTabIndex = index);
          _fetchAndProcessData();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.textDarkGrey : AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? null
                : Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textLightGrey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Min-maks geçmişi",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDarkGrey,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxY,
                minY: _getMinY,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int idx = value.toInt();
                        // 31 günde 5'er adım, 7 günde hepsini göster
                        if (_selectedTabIndex == 1 && idx % 5 != 0)
                          return const SizedBox();
                        final String label = _selectedTabIndex == 2
                            ? "${idx + 1}A"
                            : "${idx + 1}";
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: AppColors.textLightGrey,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: AppColors.textLightGrey,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: widget.sensorType == 'nabiz'
                      ? 30
                      : (widget.sensorType == 'spo2' ? 5 : 2),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.1),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_processedChartData.length, (index) {
                  final double minVal = _processedChartData[index][0];
                  final double maxVal = _processedChartData[index][1];
                  // min == max ise (varsayılan veri) çubuğu soluk göster
                  final bool isDefault = (minVal == maxVal);
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: maxVal,
                        fromY: minVal,
                        color: isDefault
                            ? _sensorColor.withOpacity(0.15)
                            : _sensorColor,
                        width: _selectedTabIndex == 1 ? 4 : 10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
