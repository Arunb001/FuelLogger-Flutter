import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../services/csv_service.dart';
import '../../models/fuel_log.dart';
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
  String? _selectedFileName;
  String _csvContent = '';
  List<FuelLog> _parsedLogs = [];
  bool _replaceExisting = false; // false = Append, true = Full Replace
  bool _isLoading = false;

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final content = await file.xFile.readAsString();

        if (content.trim().isNotEmpty) {
          final parsed = CsvService.parseCsv(
            content,
            userId: 'preview',
            vehicleId: 'preview',
          );

          setState(() {
            _selectedFileName = file.name;
            _csvContent = content;
            _parsedLogs = parsed;
          });

          if (mounted) {
            showCustomSnackBar(
              context,
              'Loaded ${file.name} (${parsed.length} log rows detected)!',
            );
          }
        } else {
          if (mounted) {
            showCustomSnackBar(context, 'The selected file is empty.', isError: true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'Failed to read file: $e', isError: true);
      }
    }
  }

  Future<void> _downloadSampleCsv() async {
    try {
      final sample = CsvService.generateSampleCsv();
      final bytes = Uint8List.fromList(utf8.encode(sample));
      final res = await FilePicker.saveFile(
        dialogTitle: 'Download sample.csv',
        fileName: 'sample_fuel_data.csv',
        bytes: bytes,
        mimeType: 'text/csv',
      );

      if (mounted && res != null) {
        showCustomSnackBar(context, 'sample.csv downloaded successfully!');
      }
    } catch (e) {
      if (mounted) {
        showCustomSnackBar(context, 'Failed to download sample: $e', isError: true);
      }
    }
  }

  Future<void> _runImport() async {
    if (_csvContent.isEmpty || _parsedLogs.isEmpty) {
      showCustomSnackBar(context, 'Please upload a .csv file first.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final garage = context.read<GarageProvider>();
      final count = await garage.importFuelLogsFromCsv(
        _csvContent,
        replaceExisting: _replaceExisting,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (count > 0) {
          Navigator.pop(context);
          showCustomSnackBar(
            context,
            'Successfully imported $count logs! Telemetry recalculated.',
          );
        } else {
          showCustomSnackBar(
            context,
            'No valid log entries found in the file. Please check file format.',
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
    final garage = context.watch<GarageProvider>();

    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 32),
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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

          // Header
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import Fuel Logs (.csv)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Target vehicle: ${garage.activeVehicleName}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
          const SizedBox(height: 20),

          // Option 1 & 2: Upload .csv + Download sample.csv
          Row(
            children: [
              // 1. Upload .csv
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickFile,
                  icon: const Icon(Icons.upload_file, size: 18, color: Colors.white),
                  label: const Text(
                    'Upload .csv',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. Download sample.csv
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _downloadSampleCsv,
                  icon: const Icon(Icons.download, size: 18, color: AppTheme.distanceBlue),
                  label: const Text(
                    'Sample .csv',
                    style: TextStyle(color: AppTheme.distanceBlue, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.distanceBlue),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Selected File Status Banner
          if (_selectedFileName != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.scaffoldBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.mileageGreen.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.mileageGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFileName!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_parsedLogs.length} fuel log entries ready to import',
                          style: const TextStyle(fontSize: 12, color: AppTheme.mileageGreen),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Option 3 & 4: Append vs Full Replace
          const Text(
            'Import Mode:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppTheme.scaffoldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                // Option 3: Append Data
                InkWell(
                  onTap: () => setState(() => _replaceExisting = false),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        Radio<bool>(
                          value: false,
                          groupValue: _replaceExisting,
                          activeColor: AppTheme.primary,
                          onChanged: (val) => setState(() => _replaceExisting = val ?? false),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Append Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Keep current logs and add new entries to the end', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Colors.white10),

                // Option 4: Full Replace Data
                InkWell(
                  onTap: () => setState(() => _replaceExisting = true),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: _replaceExisting,
                          activeColor: Colors.amber,
                          onChanged: (val) => setState(() => _replaceExisting = val ?? true),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Full Replace Data', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Wipe existing logs for this vehicle and replace completely', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Confirm Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_isLoading || _parsedLogs.isEmpty) ? null : _runImport,
              style: ElevatedButton.styleFrom(
                backgroundColor: _replaceExisting ? Colors.amber.shade800 : AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _selectedFileName == null
                          ? 'Select a .csv File Above'
                          : (_replaceExisting
                              ? 'Replace All with ${_parsedLogs.length} Logs'
                              : 'Append ${_parsedLogs.length} Logs'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
