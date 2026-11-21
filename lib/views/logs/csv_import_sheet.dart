import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../services/csv_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';

class CsvImportSheet extends StatefulWidget {
  const CsvImportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CsvImportSheet(),
    );
  }

  @override
  State<CsvImportSheet> createState() => _CsvImportSheetState();
}

class _CsvImportSheetState extends State<CsvImportSheet> {
  final TextEditingController _csvController = TextEditingController();
  bool _replaceExisting = false;
  bool _isLoading = false;
  int _parsedRowCount = 0;

  @override
  void initState() {
    super.initState();
    _csvController.addListener(_updateRowCount);
  }

  @override
  void dispose() {
    _csvController.removeListener(_updateRowCount);
    _csvController.dispose();
    super.dispose();
  }

  void _updateRowCount() {
    final text = _csvController.text.trim();
    if (text.isEmpty) {
      if (_parsedRowCount != 0) setState(() => _parsedRowCount = 0);
      return;
    }
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    // Exclude header row if present
    int count = lines.length;
    if (count > 0 && lines.first.toLowerCase().contains('odo')) {
      count = count - 1;
    }
    if (_parsedRowCount != count) {
      setState(() => _parsedRowCount = count.clamp(0, 9999));
    }
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final content = await file.xFile.readAsString();

        if (content.isNotEmpty) {
          setState(() {
            _csvController.text = content;
          });
          if (mounted) {
            showCustomSnackBar(context, 'Loaded ${file.name} successfully!');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'Failed to read file: $e', isError: true);
      }
    }
  }

  void _loadSampleData() {
    setState(() {
      _csvController.text = CsvService.generateSampleCsv();
    });
    showCustomSnackBar(context, 'Sample test data loaded! Tap "Start Import" to proceed.');
  }

  void _copyTemplate() {
    Clipboard.setData(ClipboardData(text: CsvService.generateSampleCsv()));
    showCustomSnackBar(context, 'Sample CSV format copied to clipboard!');
  }

  Future<void> _runImport() async {
    final text = _csvController.text.trim();
    if (text.isEmpty) {
      showCustomSnackBar(context, 'Please paste CSV data or pick a file first.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final garage = context.read<GarageProvider>();
      final imported = await garage.importFuelLogsFromCsv(
        text,
        replaceExisting: _replaceExisting,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (imported > 0) {
          Navigator.pop(context);
          showCustomSnackBar(
            context,
            'Successfully imported $imported logs! Telemetry recalculated.',
          );
        } else {
          showCustomSnackBar(
            context,
            'No valid fuel log rows found in CSV. Please verify column headers.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showCustomSnackBar(context, 'Import failed: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset > 0 ? bottomInset + 16 : 30,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.file_upload_outlined, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulk CSV Import',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Import real fuel logs automatically',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Actions: Pick File, Load Sample, Copy Template
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open, size: 16, color: Colors.white),
                  label: const Text('Pick .CSV File', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loadSampleData,
                  icon: const Icon(Icons.auto_fix_high, size: 16, color: AppTheme.mileageGreen),
                  label: const Text('Load Sample Data', style: TextStyle(color: AppTheme.mileageGreen, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.mileageGreen.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _copyTemplate,
                  icon: const Icon(Icons.copy, size: 16, color: AppTheme.distanceBlue),
                  label: const Text('Copy Template', style: TextStyle(color: AppTheme.distanceBlue, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.distanceBlue.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // CSV Text Area
            TextField(
              controller: _csvController,
              maxLines: 8,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.white70,
              ),
              decoration: InputDecoration(
                hintText: "Paste CSV lines or pick file above...\nFormat:\nrun_id,date,fuel_type,odometer,fuel_cost,liters_to_fill,fuel_density,fill_flag\n1,2026-11-01,XP95,1929,801.00,9.30,750.7,F",
                hintStyle: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                filled: true,
                fillColor: AppTheme.scaffoldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Row Count Counter
            Row(
              children: [
                Icon(
                  _parsedRowCount > 0 ? Icons.check_circle_outline : Icons.info_outline,
                  size: 16,
                  color: _parsedRowCount > 0 ? AppTheme.mileageGreen : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  _parsedRowCount > 0
                      ? '$_parsedRowCount log entries ready for import'
                      : 'Paste data or tap "Load Sample Data"',
                  style: TextStyle(
                    fontSize: 12,
                    color: _parsedRowCount > 0 ? AppTheme.mileageGreen : Colors.grey,
                    fontWeight: _parsedRowCount > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Mode Selector: Append vs Replace
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.scaffoldBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _replaceExisting = false),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Radio<bool>(
                            value: false,
                            groupValue: _replaceExisting,
                            activeColor: AppTheme.primary,
                            onChanged: (val) => setState(() => _replaceExisting = val ?? false),
                          ),
                          const Text('Append', style: TextStyle(fontSize: 13, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _replaceExisting = true),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Radio<bool>(
                            value: true,
                            groupValue: _replaceExisting,
                            activeColor: Colors.amber,
                            onChanged: (val) => setState(() => _replaceExisting = val ?? true),
                          ),
                          const Text('Replace All', style: TextStyle(fontSize: 13, color: Colors.amber)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _runImport,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_upload_outlined, color: Colors.white),
                label: Text(
                  _isLoading
                      ? 'Importing & Calculating Telemetry...'
                      : 'Import ${_parsedRowCount > 0 ? "$_parsedRowCount Logs" : "Logs"}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
