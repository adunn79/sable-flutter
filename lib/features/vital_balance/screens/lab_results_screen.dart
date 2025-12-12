import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/lab_result.dart';
import '../services/health_data_service.dart';

/// Lab Results Screen - View and manage lab test results
/// 
/// Best-in-class features from VitalDots / MyChart:
/// - Category filtering
/// - Trend charts for each test
/// - Normal range indicators
/// - Export to PDF
class LabResultsScreen extends StatefulWidget {
  const LabResultsScreen({super.key});

  @override
  State<LabResultsScreen> createState() => _LabResultsScreenState();
}

class _LabResultsScreenState extends State<LabResultsScreen> {
  String _selectedCategory = 'All';
  List<LabResult> _allResults = [];
  List<LabResult> _filteredResults = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadResults();
  }
  
  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    
    final results = await HealthDataService.getAllLabResults();
    
    setState(() {
      _allResults = results;
      _filteredResults = results;
      _isLoading = false;
    });
  }
  
  void _filterByCategory(String category) {
    setState(() {
      _selectedCategory = category;
      if (category == 'All') {
        _filteredResults = _allResults;
      } else {
        _filteredResults = _allResults.where((r) => r.category == category).toList();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Lab Results',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            tooltip: 'Export',
            onPressed: _exportResults,
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: _showAddResultDialog,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Category Filter
                _buildCategoryFilter(),
                
                // Results List
                Expanded(
                  child: _filteredResults.isEmpty
                      ? _buildEmptyState()
                      : _buildResultsList(),
                ),
              ],
            ),
    );
  }
  
  Widget _buildCategoryFilter() {
    final categories = ['All', ...LabCategories.all];
    
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == _selectedCategory;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (_) => _filterByCategory(cat),
              backgroundColor: Colors.white.withOpacity(0.05),
              selectedColor: Colors.blue.withOpacity(0.3),
              labelStyle: GoogleFonts.inter(
                color: isSelected ? Colors.blue[200] : Colors.white70,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected ? Colors.blue.withOpacity(0.5) : Colors.transparent,
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.testTubes, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'No lab results yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan a lab report or add results manually',
            style: GoogleFonts.inter(
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddResultDialog,
            icon: const Icon(LucideIcons.plus),
            label: const Text('Add Lab Result'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.withOpacity(0.2),
              foregroundColor: Colors.blue[200],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultsList() {
    // Group by test name for trend display
    final grouped = <String, List<LabResult>>{};
    for (final result in _filteredResults) {
      grouped.putIfAbsent(result.testName, () => []).add(result);
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final testName = grouped.keys.elementAt(index);
        final results = grouped[testName]!;
        return _buildTestCard(testName, results);
      },
    );
  }
  
  Widget _buildTestCard(String testName, List<LabResult> results) {
    final latest = results.first;
    final hasHistory = results.length > 1;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: latest.isNormal 
              ? Colors.white.withOpacity(0.1)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _buildStatusIcon(latest),
          title: Text(
            testName,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                latest.displayValue,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: latest.isNormal ? Colors.white : Colors.orange,
                ),
              ),
              Text(
                'Range: ${latest.referenceRangeDisplay}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(latest.testDate),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
              if (hasHistory)
                Text(
                  '${results.length} readings',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.blue[300],
                  ),
                ),
            ],
          ),
          children: [
            if (hasHistory) _buildTrendChart(results),
            _buildHistoryList(results),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusIcon(LabResult result) {
    if (result.isCritical) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.alertCircle, color: Colors.red, size: 20),
      );
    }
    
    if (!result.isNormal) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.alertTriangle, color: Colors.orange, size: 20),
      );
    }
    
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(LucideIcons.checkCircle, color: Colors.green, size: 20),
    );
  }
  
  Widget _buildTrendChart(List<LabResult> results) {
    final spots = results.reversed.toList().asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();
    
    final latest = results.first;
    
    return Container(
      height: 150,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: spots.length.toDouble() - 1,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: latest.isNormal ? Colors.green : Colors.orange,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeColor: barData.color ?? Colors.green,
                    strokeWidth: 2,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: (latest.isNormal ? Colors.green : Colors.orange)
                    .withOpacity(0.1),
              ),
            ),
            // Reference range lines
            if (latest.referenceRangeLow != null)
              LineChartBarData(
                spots: [
                  FlSpot(0, latest.referenceRangeLow!),
                  FlSpot(spots.length.toDouble() - 1, latest.referenceRangeLow!),
                ],
                color: Colors.white24,
                dashArray: [5, 5],
                dotData: const FlDotData(show: false),
              ),
            if (latest.referenceRangeHigh != null)
              LineChartBarData(
                spots: [
                  FlSpot(0, latest.referenceRangeHigh!),
                  FlSpot(spots.length.toDouble() - 1, latest.referenceRangeHigh!),
                ],
                color: Colors.white24,
                dashArray: [5, 5],
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHistoryList(List<LabResult> results) {
    return Column(
      children: results.map((r) => ListTile(
        dense: true,
        leading: Text(
          r.displayValue,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            color: r.isNormal ? Colors.white70 : Colors.orange,
          ),
        ),
        title: Text(
          _formatDate(r.testDate),
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white54,
          ),
        ),
        subtitle: r.labName != null 
            ? Text(
                r.labName!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white38,
                ),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.white24),
          onPressed: () => _deleteResult(r),
        ),
      )).toList(),
    );
  }
  
  void _showAddResultDialog() {
    // Show dialog to add a new lab result
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddLabResultSheet(
        onSave: (result) async {
          await HealthDataService.addLabResult(
            testName: result['testName'],
            value: result['value'],
            unit: result['unit'],
            testDate: result['testDate'],
            referenceRangeLow: result['rangeLow'],
            referenceRangeHigh: result['rangeHigh'],
            category: result['category'],
          );
          _loadResults();
        },
      ),
    );
  }
  
  Future<void> _deleteResult(LabResult result) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('Delete Result?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove ${result.testName} from ${_formatDate(result.testDate)}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await HealthDataService.deleteLabResult(result.id);
      _loadResults();
    }
  }
  
  void _exportResults() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon')),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

/// Sheet for adding a new lab result
class _AddLabResultSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  
  const _AddLabResultSheet({required this.onSave});

  @override
  State<_AddLabResultSheet> createState() => _AddLabResultSheetState();
}

class _AddLabResultSheetState extends State<_AddLabResultSheet> {
  final _formKey = GlobalKey<FormState>();
  String _testName = '';
  double _value = 0;
  String _unit = 'mg/dL';
  double? _rangeLow;
  double? _rangeHigh;
  String _category = 'General';
  DateTime _testDate = DateTime.now();
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Lab Result',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              
              // Test Name dropdown with common tests
              DropdownButtonFormField<String>(
                decoration: _inputDecoration('Test Name'),
                dropdownColor: const Color(0xFF2A2A34),
                value: _testName.isEmpty ? null : _testName,
                items: [
                  const DropdownMenuItem(value: '', child: Text('Select or enter...')),
                  ...CommonLabTests.all.map((t) => DropdownMenuItem(
                    value: t['name'] as String,
                    child: Text(t['name'] as String),
                  )),
                ],
                onChanged: (v) {
                  if (v != null && v.isNotEmpty) {
                    final test = CommonLabTests.all.firstWhere(
                      (t) => t['name'] == v,
                      orElse: () => {},
                    );
                    setState(() {
                      _testName = v;
                      if (test.isNotEmpty) {
                        _unit = test['unit'] as String? ?? 'mg/dL';
                        _rangeLow = (test['low'] as num?)?.toDouble();
                        _rangeHigh = (test['high'] as num?)?.toDouble();
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              
              // Value and unit
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      decoration: _inputDecoration('Value'),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (v) => _value = double.tryParse(v) ?? 0,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: _inputDecoration('Unit'),
                      initialValue: _unit,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (v) => _unit = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Reference range
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: _inputDecoration('Range Low'),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      initialValue: _rangeLow?.toString(),
                      onChanged: (v) => _rangeLow = double.tryParse(v),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('-', style: TextStyle(color: Colors.white54)),
                  ),
                  Expanded(
                    child: TextFormField(
                      decoration: _inputDecoration('Range High'),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      initialValue: _rangeHigh?.toString(),
                      onChanged: (v) => _rangeHigh = double.tryParse(v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save Result'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: Colors.white54),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
    );
  }
  
  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSave({
        'testName': _testName,
        'value': _value,
        'unit': _unit,
        'testDate': _testDate,
        'rangeLow': _rangeLow,
        'rangeHigh': _rangeHigh,
        'category': _category,
      });
      Navigator.pop(context);
    }
  }
}
