import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:uuid/uuid.dart';
import '../models/prescription.dart';
import '../services/prescription_service.dart';
import '../services/prescription_ocr_service.dart';

/// Screen for editing or creating a prescription
class PrescriptionEditScreen extends StatefulWidget {
  final Prescription? prescription;
  final PrescriptionScanResult? scanResult;
  final String? photoPath;

  const PrescriptionEditScreen({
    super.key,
    this.prescription,
    this.scanResult,
    this.photoPath,
  });

  @override
  State<PrescriptionEditScreen> createState() => _PrescriptionEditScreenState();
}

class _PrescriptionEditScreenState extends State<PrescriptionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _strengthController;
  late TextEditingController _directionsController;
  late TextEditingController _pharmacyNameController;
  late TextEditingController _pharmacyPhoneController;
  late TextEditingController _pharmacyAddressController;
  late TextEditingController _rxNumberController;
  late TextEditingController _prescriberController;
  late TextEditingController _notesController;
  
  String _dosageForm = DosageForms.tablet;
  int _refillsRemaining = 0;
  int? _quantityDispensed;
  int? _daysSupply;
  DateTime? _dateFilled;
  DateTime? _expirationDate;
  bool _reminderEnabled = false;
  bool _isSaving = false;
  
  bool get _isEditing => widget.prescription != null;

  @override
  void initState() {
    super.initState();
    
    final p = widget.prescription;
    final s = widget.scanResult;
    
    _nameController = TextEditingController(text: p?.medicationName ?? s?.medicationName ?? '');
    _brandController = TextEditingController(text: p?.brandName ?? '');
    _strengthController = TextEditingController(text: p?.strength ?? s?.strength ?? '');
    _directionsController = TextEditingController(text: p?.directions ?? s?.directions ?? '');
    _pharmacyNameController = TextEditingController(text: p?.pharmacyName ?? s?.pharmacyName ?? '');
    _pharmacyPhoneController = TextEditingController(text: p?.pharmacyPhone ?? s?.pharmacyPhone ?? '');
    _pharmacyAddressController = TextEditingController(text: p?.pharmacyAddress ?? s?.pharmacyAddress ?? '');
    _rxNumberController = TextEditingController(text: p?.rxNumber ?? s?.rxNumber ?? '');
    _prescriberController = TextEditingController(text: p?.prescriberName ?? s?.prescriberName ?? '');
    _notesController = TextEditingController(text: p?.notes ?? '');
    
    if (p != null) {
      _dosageForm = p.dosageForm;
      _refillsRemaining = p.refillsRemaining;
      _quantityDispensed = p.quantityDispensed;
      _daysSupply = p.daysSupply;
      _dateFilled = p.dateFilled;
      _expirationDate = p.expirationDate;
      _reminderEnabled = p.reminderEnabled;
    } else if (s != null) {
      _refillsRemaining = s.refillsRemaining ?? 0;
      _quantityDispensed = s.quantityDispensed;
      _dateFilled = s.dateFilled;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _strengthController.dispose();
    _directionsController.dispose();
    _pharmacyNameController.dispose();
    _pharmacyPhoneController.dispose();
    _pharmacyAddressController.dispose();
    _rxNumberController.dispose();
    _prescriberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Medication' : 'Add Medication',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(LucideIcons.trash2, color: Colors.red),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Scanned data notice
            if (widget.scanResult != null)
              _buildInfoBanner(
                'Scanned data shown below. Please verify and correct if needed.',
                AelianaColors.plasmaCyan,
              ),
            
            // === MEDICATION INFO ===
            _buildSectionHeader('Medication Info', LucideIcons.pill),
            _buildTextField(
              controller: _nameController,
              label: 'Medication Name *',
              hint: 'e.g., Metformin HCL',
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            _buildTextField(
              controller: _brandController,
              label: 'Brand Name (optional)',
              hint: 'e.g., Glucophage',
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _strengthController,
                    label: 'Strength *',
                    hint: 'e.g., 500mg',
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: 'Form',
                    value: _dosageForm,
                    items: DosageForms.all,
                    onChanged: (v) => setState(() => _dosageForm = v!),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // === DIRECTIONS ===
            _buildSectionHeader('Directions', LucideIcons.fileText),
            _buildTextField(
              controller: _directionsController,
              label: 'How to Take *',
              hint: 'e.g., Take 1 tablet twice daily with meals',
              maxLines: 2,
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            
            const SizedBox(height: 24),
            
            // === PHARMACY INFO ===
            _buildSectionHeader('Pharmacy', LucideIcons.building2),
            _buildTextField(
              controller: _pharmacyNameController,
              label: 'Pharmacy Name',
              hint: 'e.g., CVS Pharmacy',
            ),
            _buildTextField(
              controller: _pharmacyPhoneController,
              label: 'Phone Number',
              hint: 'e.g., (555) 123-4567',
              keyboardType: TextInputType.phone,
            ),
            _buildTextField(
              controller: _pharmacyAddressController,
              label: 'Address',
              hint: 'e.g., 123 Main St, City, ST 12345',
            ),
            _buildTextField(
              controller: _rxNumberController,
              label: 'Rx Number',
              hint: 'e.g., 1234567',
            ),
            
            const SizedBox(height: 24),
            
            // === PRESCRIBER ===
            _buildSectionHeader('Prescriber', LucideIcons.stethoscope),
            _buildTextField(
              controller: _prescriberController,
              label: 'Doctor Name',
              hint: 'e.g., Dr. John Smith',
            ),
            
            const SizedBox(height: 24),
            
            // === QUANTITY & REFILLS ===
            _buildSectionHeader('Quantity & Dates', LucideIcons.calendar),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    label: 'Quantity',
                    value: _quantityDispensed,
                    onChanged: (v) => setState(() => _quantityDispensed = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField(
                    label: 'Days Supply',
                    value: _daysSupply,
                    onChanged: (v) => setState(() => _daysSupply = v),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    label: 'Refills Left',
                    value: _refillsRemaining,
                    onChanged: (v) => setState(() => _refillsRemaining = v ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Container()), // Spacer
              ],
            ),
            _buildDatePicker(
              label: 'Date Filled',
              value: _dateFilled,
              onChanged: (d) => setState(() => _dateFilled = d),
            ),
            _buildDatePicker(
              label: 'Expiration Date',
              value: _expirationDate,
              onChanged: (d) => setState(() => _expirationDate = d),
            ),
            
            const SizedBox(height: 24),
            
            // === REMINDERS ===
            _buildSectionHeader('Reminders', LucideIcons.bell),
            _buildToggle(
              label: 'Set refill reminder',
              subtitle: 'Get notified 7 days before running out',
              value: _reminderEnabled,
              onChanged: (v) => setState(() => _reminderEnabled = v),
            ),
            
            const SizedBox(height: 24),
            
            // === NOTES ===
            _buildSectionHeader('Notes', LucideIcons.stickyNote),
            _buildTextField(
              controller: _notesController,
              label: 'Personal Notes',
              hint: 'Any additional notes...',
              maxLines: 3,
            ),
            
            const SizedBox(height: 32),
            
            // Save button
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AelianaColors.plasmaCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _isEditing ? 'Save Changes' : 'Add Medication',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
            
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AelianaColors.hyperGold, size: 18),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.inter(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.inter(color: Colors.white54),
          hintStyle: GoogleFonts.inter(color: Colors.white30),
          filled: true,
          fillColor: AelianaColors.obsidian,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AelianaColors.plasmaCyan),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        onChanged: onChanged,
        style: GoogleFonts.inter(color: Colors.white),
        dropdownColor: AelianaColors.obsidian,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.white54),
          filled: true,
          fillColor: AelianaColors.obsidian,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white12),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value?.toString() ?? '',
        keyboardType: TextInputType.number,
        onChanged: (v) => onChanged(int.tryParse(v)),
        style: GoogleFonts.inter(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.white54),
          filled: true,
          fillColor: AelianaColors.obsidian,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white12),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (date != null) onChanged(date);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AelianaColors.obsidian,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value != null
                          ? '${value.month}/${value.day}/${value.year}'
                          : 'Tap to select',
                      style: GoogleFonts.inter(
                        color: value != null ? Colors.white : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.calendar, color: Colors.white38, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AelianaColors.obsidian,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(color: Colors.white)),
                Text(subtitle, style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AelianaColors.plasmaCyan,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final prescription = _isEditing
          ? widget.prescription!.copyWith(
              medicationName: _nameController.text,
              brandName: _brandController.text.isEmpty ? null : _brandController.text,
              strength: _strengthController.text,
              dosageForm: _dosageForm,
              directions: _directionsController.text,
              pharmacyName: _pharmacyNameController.text.isEmpty ? null : _pharmacyNameController.text,
              pharmacyPhone: _pharmacyPhoneController.text.isEmpty ? null : _pharmacyPhoneController.text,
              pharmacyAddress: _pharmacyAddressController.text.isEmpty ? null : _pharmacyAddressController.text,
              rxNumber: _rxNumberController.text.isEmpty ? null : _rxNumberController.text,
              prescriberName: _prescriberController.text.isEmpty ? null : _prescriberController.text,
              refillsRemaining: _refillsRemaining,
              quantityDispensed: _quantityDispensed,
              daysSupply: _daysSupply,
              dateFilled: _dateFilled,
              expirationDate: _expirationDate,
              reminderEnabled: _reminderEnabled,
              notes: _notesController.text.isEmpty ? null : _notesController.text,
            )
          : Prescription(
              id: const Uuid().v4(),
              medicationName: _nameController.text,
              brandName: _brandController.text.isEmpty ? null : _brandController.text,
              strength: _strengthController.text,
              dosageForm: _dosageForm,
              directions: _directionsController.text,
              pharmacyName: _pharmacyNameController.text.isEmpty ? null : _pharmacyNameController.text,
              pharmacyPhone: _pharmacyPhoneController.text.isEmpty ? null : _pharmacyPhoneController.text,
              pharmacyAddress: _pharmacyAddressController.text.isEmpty ? null : _pharmacyAddressController.text,
              rxNumber: _rxNumberController.text.isEmpty ? null : _rxNumberController.text,
              prescriberName: _prescriberController.text.isEmpty ? null : _prescriberController.text,
              refillsRemaining: _refillsRemaining,
              quantityDispensed: _quantityDispensed,
              daysSupply: _daysSupply,
              dateFilled: _dateFilled,
              expirationDate: _expirationDate,
              reminderEnabled: _reminderEnabled,
              notes: _notesController.text.isEmpty ? null : _notesController.text,
            );
      
      if (_isEditing) {
        await PrescriptionService.updatePrescription(prescription);
      } else {
        await PrescriptionService.addPrescription(
          medicationName: prescription.medicationName,
          strength: prescription.strength,
          directions: prescription.directions,
          brandName: prescription.brandName,
          dosageForm: prescription.dosageForm,
          pharmacyName: prescription.pharmacyName,
          pharmacyPhone: prescription.pharmacyPhone,
          pharmacyAddress: prescription.pharmacyAddress,
          rxNumber: prescription.rxNumber,
          prescriberName: prescription.prescriberName,
          refillsRemaining: prescription.refillsRemaining,
          quantityDispensed: prescription.quantityDispensed,
          daysSupply: prescription.daysSupply,
          dateFilled: prescription.dateFilled,
          expirationDate: prescription.expirationDate,
          notes: prescription.notes,
        );
      }
      
      // Schedule reminder if enabled
      if (_reminderEnabled && _daysSupply != null && _dateFilled != null) {
        await PrescriptionService.scheduleRefillReminder(prescription);
      }
      
      if (mounted) {
        Navigator.pop(context, prescription);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AelianaColors.obsidian,
        title: Text(
          'Delete Medication?',
          style: GoogleFonts.spaceGrotesk(color: Colors.white),
        ),
        content: Text(
          'This will permanently remove ${widget.prescription!.displayName}.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await PrescriptionService.deletePrescription(widget.prescription!.id);
              if (mounted) Navigator.pop(context);
            },
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
