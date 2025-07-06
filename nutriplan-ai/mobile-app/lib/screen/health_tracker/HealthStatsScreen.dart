import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/MedicalDataService.dart';
import '../../models/UserModel.dart';
import '../../components/AnimatedLoader.dart';
import '../../utils/Constants.dart';

class HealthStatsScreen extends StatefulWidget {
  final String userId;

  const HealthStatsScreen({super.key, required this.userId});

  @override
  _HealthStatsScreenState createState() => _HealthStatsScreenState();
}

class _HealthStatsScreenState extends State<HealthStatsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _healthData = [];

  @override
  void initState() {
    super.initState();
    _fetchHealthData();
  }

  Future<void> _fetchHealthData() async {
    try {
      final data = await MedicalDataService().getUserHealthStats(widget.userId);
      setState(() {
        _healthData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to load health stats.";
        _isLoading = false;
      });
    }
  }

  Widget _buildChartSection() {
    if (_healthData.isEmpty) {
      return const Center(child: Text('No health data available.'));
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        const Text(
          'Weight Progress (kg)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= _healthData.length) return const SizedBox.shrink();
                      final date = _healthData[index]['date'].toString().substring(5, 10); // MM-DD
                      return Text(date, style: const TextStyle(fontSize: 10));
                    },
                    reservedSize: 28,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) => Text('${value.toInt()} kg'),
                    reservedSize: 40,
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: _healthData
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value['weight']?.toDouble() ?? 0))
                      .toList(),
                  isCurved: true,
                  barWidth: 3,
                  color: primaryColor,
                  belowBarData: BarAreaData(show: false),
                  dotData: FlDotData(show: true),
                ),
              ],
              gridData: FlGridData(show: true),
              borderData: FlBorderData(show: true),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildHealthSummary(),
      ],
    );
  }

  Widget _buildHealthSummary() {
    final latest = _healthData.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Latest Metrics:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text("Date: ${latest['date']}"),
        Text("Weight: ${latest['weight']} kg"),
        Text("Height: ${latest['height']} cm"),
        Text("BMI: ${_calculateBMI(latest['weight'], latest['height']).toStringAsFixed(2)}"),
        Text("Heart Rate: ${latest['heart_rate']} bpm"),
        Text("Blood Pressure: ${latest['bp']}"),
      ],
    );
  }

  double _calculateBMI(dynamic weight, dynamic height) {
    try {
      final w = double.tryParse(weight.toString()) ?? 0;
      final h = double.tryParse(height.toString()) ?? 0;
      if (h == 0) return 0;
      final heightInMeters = h / 100;
      return w / (heightInMeters * heightInMeters);
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Stats'),
      ),
      body: _isLoading
          ? const Center(child: AnimatedLoader())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(child: _buildChartSection()),
                ),
    );
  }
}
