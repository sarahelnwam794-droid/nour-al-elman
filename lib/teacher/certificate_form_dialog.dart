import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'employee_certificate_model.dart';
import '../utils/server_date_utils.dart';
import '../services/certificate_service.dart';

const Color _primaryOrange = Color(0xFFC66422);
const Color _darkBlue = Color(0xFF2E3542);

Future<bool?> showCertificateFormDialog({
  required BuildContext context,
  required int empId,
  EmployeeCertificate? certificate,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CertificateFormDialog(
      empId: empId,
      certificate: certificate,
    ),
  );
}

class CertificateFormDialog extends StatefulWidget {
  final int empId;
  final EmployeeCertificate? certificate;

  const CertificateFormDialog({
    super.key,
    required this.empId,
    this.certificate,
  });

  bool get isEdit => certificate != null;

  @override
  State<CertificateFormDialog> createState() => _CertificateFormDialogState();
}

class _CertificateFormDialogState extends State<CertificateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _certificateService = CertificateService();

  late final TextEditingController _cerNameController;
  late final TextEditingController _cerFromController;
  late final TextEditingController _courseNameController;
  late final TextEditingController _placeController;
  late final TextEditingController _gradeController;

  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _filePath;
  String? _fileName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final cert = widget.certificate;
    _cerNameController = TextEditingController(text: cert?.cerName ?? '');
    _cerFromController = TextEditingController(text: cert?.cerFrom ?? '');
    _courseNameController = TextEditingController(text: cert?.courseName ?? '');
    _placeController = TextEditingController(text: cert?.place ?? '');
    _gradeController = TextEditingController(text: cert?.grade ?? '');
    _dateFrom = ServerDateUtils.parseFlexibleDate(cert?.dateFrom) ?? DateTime.now();
    _dateTo = ServerDateUtils.parseFlexibleDate(cert?.dateTo) ?? DateTime.now();
    if (cert?.cerFile != null && cert!.cerFile!.isNotEmpty && cert.cerFile != 'null') {
      _fileName = cert.cerFile!.split('/').last;
    }
  }

  @override
  void dispose() {
    _cerNameController.dispose();
    _cerFromController.dispose();
    _courseNameController.dispose();
    _placeController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'dd----yyyy';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateFrom == null || _dateTo == null) {
      _showMessage('يرجى اختيار تاريخ البدء والانتهاء', isError: true);
      return;
    }
    if (!widget.isEdit && (_filePath == null || _filePath!.isEmpty)) {
      _showMessage('يرجى اختيار ملف الشهادة', isError: true);
      return;
    }

    if (widget.isEdit && widget.certificate?.id == null) {
      _showMessage('تعذر تعديل الدورة: المعرف غير متوفر', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final result = widget.isEdit
        ? await _certificateService.updateCertificate(
            id: widget.certificate!.id!,
            empId: widget.empId,
            cerName: _cerNameController.text.trim(),
            cerFrom: _cerFromController.text.trim(),
            courseName: _courseNameController.text.trim(),
            place: _placeController.text.trim(),
            grade: _gradeController.text.trim(),
            dateFrom: _dateFrom!,
            dateTo: _dateTo!,
            filePath: _filePath,
          )
        : await _certificateService.saveCertificate(
            empId: widget.empId,
            cerName: _cerNameController.text.trim(),
            cerFrom: _cerFromController.text.trim(),
            courseName: _courseNameController.text.trim(),
            place: _placeController.text.trim(),
            grade: _gradeController.text.trim(),
            dateFrom: _dateFrom!,
            dateTo: _dateTo!,
            filePath: _filePath!,
          );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
      return;
    }

    _showMessage(result['error']?.toString() ?? 'فشل حفظ البيانات', isError: true);
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Almarai')),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.isEdit ? 'تعديل دورة' : 'شهادات الشيخ',
                          style: const TextStyle(
                            fontFamily: 'Almarai',
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: _darkBlue,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildField('اسم الشهادة *', _cerNameController, 'ادخل اسم الشهادة'),
                  const SizedBox(height: 12),
                  _buildFileField(),
                  const SizedBox(height: 12),
                  _buildField('الجهة المانحة للشهادة *', _cerFromController, 'ادخل الجهة المانحة'),
                  const SizedBox(height: 12),
                  _buildField('اسم الدورة *', _courseNameController, 'ادخل اسم الدورة'),
                  const SizedBox(height: 12),
                  _buildField('المكان *', _placeController, 'ادخل المكان'),
                  const SizedBox(height: 12),
                  _buildField('التقييم *', _gradeController, 'ادخل التقييم'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildDateField('تاريخ البدء *', _dateFrom, () => _pickDate(isFrom: true))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDateField('تاريخ الانتهاء *', _dateTo, () => _pickDate(isFrom: false))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('تأكيد', style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('إلغاء', style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Almarai', fontSize: 13, color: Colors.redAccent)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: (value) => (value == null || value.trim().isEmpty) ? 'حقل مطلوب' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontFamily: 'Almarai', fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildFileField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isEdit ? 'ملف الشهادة (اختياري)' : 'ملف الشهادة *',
          style: const TextStyle(fontFamily: 'Almarai', fontSize: 13, color: Colors.redAccent),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.upload_file, color: _primaryOrange),
          label: Text(
            _fileName ?? 'Choose file',
            style: const TextStyle(fontFamily: 'Almarai', color: _darkBlue),
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            alignment: Alignment.centerRight,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Almarai', fontSize: 13, color: Colors.redAccent)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: const Icon(Icons.calendar_today, size: 18),
            ),
            child: Text(_formatDate(date), style: const TextStyle(fontFamily: 'Almarai')),
          ),
        ),
      ],
    );
  }
}
