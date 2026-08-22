import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border, BorderStyle;
import '../../core/theme/theme.dart';
import '../../core/services/supabase_service.dart';
import '../../models/models.dart';

class MavioBulkImportScreen extends StatefulWidget {
  final String importType; // 'vehicle' | 'driver' | 'student'
  final SupabaseService db;
  final List<Map<String, dynamic>> fleet; // To resolve assigned vehicle IDs

  const MavioBulkImportScreen({
    super.key,
    required this.importType,
    required this.db,
    required this.fleet,
  });

  @override
  State<MavioBulkImportScreen> createState() => _MavioBulkImportScreenState();
}

class _MavioBulkImportScreenState extends State<MavioBulkImportScreen> {
  final TextEditingController _csvController = TextEditingController();
  List<Map<String, String>> _parsedRows = [];
  String _validationMessage = "";
  bool _isLoading = false;

  List<String> get _requiredHeaders {
    switch (widget.importType) {
      case 'vehicle':
        return ['Bus Name', 'Registration Number'];
      case 'driver':
        return ['Name', 'Email', 'Mobile Number', 'Password', 'Assigned Bus'];
      case 'student':
        return [
          'Student Name',
          'Roll Number',
          'Date of Birth',
          'Mobile Number',
          'Assigned Bus',
        ];
      default:
        return [];
    }
  }

  String get _sampleCsv {
    switch (widget.importType) {
      case 'vehicle':
        return 'Bus Name, Registration Number\nBUS 04, TN 38 AB 9999\nBUS 05, TN 38 CD 5555';
      case 'driver':
        return 'Name, Email, Mobile Number, Password, Assigned Bus\nSarah Connor, sarah@mavio.com, 9876543210, mavio123, BUS 03\nJohn Connor, john@mavio.com, 9876543211, mavio123, BUS 04';
      case 'student':
        return 'Student Name, Roll Number, Date of Birth, Mobile Number, Assigned Bus\nJohn Doe, 12345, 05062002, 9876543220, BUS 03\nJane Doe, 12346, 12102001, 9876543221, BUS 04';
      default:
        return '';
    }
  }

  List<Map<String, String>> _parseCsv(
    String csvText,
    List<String> requiredFields,
  ) {
    final List<Map<String, String>> list = [];
    final List<String> lines = csvText.split('\n');
    if (lines.isEmpty) return list;

    // Headers line
    final String firstLine = lines.first.trim();
    if (firstLine.isEmpty) return list;

    // Detect separator: Tab or Comma
    final String separator = firstLine.contains('\t') ? '\t' : ',';
    final List<String> headers = firstLine
        .split(separator)
        .map((h) => h.trim())
        .toList();

    // Verify required headers are present
    for (var f in requiredFields) {
      if (!headers.any((h) => h.toLowerCase() == f.toLowerCase())) {
        return list; // Missing required columns
      }
    }

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final List<String> cells = line.split(separator);
      final Map<String, String> row = {};

      for (int c = 0; c < headers.length; c++) {
        final headerVal = headers[c];
        final String cellVal = c < cells.length ? cells[c].trim() : '';

        // Match with required columns case-insensitively
        for (var req in requiredFields) {
          if (headerVal.toLowerCase() == req.toLowerCase()) {
            row[req] = cellVal;
          }
        }
      }
      list.add(row);
    }
    return list;
  }

  void _validateData() {
    final text = _csvController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _parsedRows = [];
        _validationMessage =
            "Spreadsheet content is empty. Please upload a file or paste content!";
      });
      return;
    }

    final parsed = _parseCsv(text, _requiredHeaders);
    setState(() {
      _parsedRows = parsed;
      _validationMessage = parsed.isNotEmpty
          ? 'Successfully parsed ${parsed.length} items. Please verify the list below.'
          : 'Failed to parse spreadsheet. Ensure column headers match exactly:\n${_requiredHeaders.join(", ")}';
    });
  }

  Future<void> _uploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: kIsWeb ? FileType.any : FileType.custom,
        allowedExtensions: kIsWeb ? null : ['csv', 'txt', 'xlsx', 'xls'],
      );
      if (result != null && result.files.isNotEmpty) {
        final fileResult = result.files.first;
        final name = fileResult.name.toLowerCase();

        if (name.endsWith('.xlsx') || name.endsWith('.xls')) {
          List<int> bytes;
          if (kIsWeb) {
            bytes = fileResult.bytes!;
          } else {
            final file = io.File(fileResult.path!);
            bytes = await file.readAsBytes();
          }

          final excel = Excel.decodeBytes(bytes);
          final List<Map<String, String>> parsedExcelRows = [];

          for (var table in excel.tables.keys) {
            final sheet = excel.tables[table]!;
            if (sheet.rows.isEmpty) continue;

            // First row has the headers
            final headerRow = sheet.rows.first;
            final List<String> headers = headerRow
                .map((cell) => cell?.value?.toString().trim() ?? '')
                .toList();

            // Verify required headers are present
            bool hasHeaders = true;
            for (var f in _requiredHeaders) {
              if (!headers.any((h) => h.toLowerCase() == f.toLowerCase())) {
                hasHeaders = false;
                break;
              }
            }
            if (!hasHeaders) continue;

            for (int i = 1; i < sheet.rows.length; i++) {
              final rowData = sheet.rows[i];
              final Map<String, String> rowMap = {};
              for (int c = 0; c < headers.length; c++) {
                if (c >= rowData.length) continue;
                final headerVal = headers[c];
                final cellVal = rowData[c]?.value?.toString().trim() ?? '';

                for (var req in _requiredHeaders) {
                  if (headerVal.toLowerCase() == req.toLowerCase()) {
                    rowMap[req] = cellVal;
                  }
                }
              }
              if (rowMap.values.any((v) => v.isNotEmpty)) {
                parsedExcelRows.add(rowMap);
              }
            }
            break;
          }

          setState(() {
            _csvController.text = "";
            _parsedRows = parsedExcelRows;
            _validationMessage = parsedExcelRows.isNotEmpty
                ? 'Successfully parsed ${parsedExcelRows.length} items from Excel spreadsheet. Please verify the list below.'
                : 'Failed to parse Excel sheet. Ensure sheet contains headers: ${_requiredHeaders.join(", ")}';
          });
        } else {
          String content = "";
          if (kIsWeb) {
            content = utf8.decode(fileResult.bytes!);
          } else {
            final file = io.File(fileResult.path!);
            content = await file.readAsString();
          }
          setState(() {
            _csvController.text = content;
          });
          _validateData();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error parsing spreadsheet file: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _saveImport() async {
    if (_parsedRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No validated data to save.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.importType == 'vehicle') {
        final org = widget.db.currentOrganization;
        final isFreeTrial = org?.subscriptionStatus == 'free_trial';
        if (isFreeTrial && (widget.fleet.length + _parsedRows.length) > 25) {
          setState(() => _isLoading = false);
          _showLimitExceededDialog();
          return;
        }
        for (var row in _parsedRows) {
          await widget.db.addVehicle(
            row['Bus Name']!,
            row['Registration Number']!,
          );
        }
      } else if (widget.importType == 'driver') {
        for (var row in _parsedRows) {
          String? vId;
          final assignedBusName = (row['Assigned Bus'] ?? '')
              .trim()
              .toUpperCase();
          if (assignedBusName.isNotEmpty) {
            for (var item in widget.fleet) {
              final v = item['vehicle'] as MavioVehicle;
              if (v.name.toUpperCase().contains(assignedBusName) ||
                  assignedBusName.contains(v.name.toUpperCase())) {
                vId = v.id;
                break;
              }
            }
          }
          await widget.db.addDriver(
            row['Name']!,
            row['Email']!,
            row['Password']!,
            vId,
            phone: row['Mobile Number'],
          );
        }
      } else if (widget.importType == 'student') {
        for (var row in _parsedRows) {
          String? vId;
          final assignedBusName = (row['Assigned Bus'] ?? '')
              .trim()
              .toUpperCase();
          if (assignedBusName.isNotEmpty) {
            for (var item in widget.fleet) {
              final v = item['vehicle'] as MavioVehicle;
              if (v.name.toUpperCase().contains(assignedBusName) ||
                  assignedBusName.contains(v.name.toUpperCase())) {
                vId = v.id;
                break;
              }
            }
          }
          final email = '${row['Roll Number']!.trim()}@mavio.student';
          await widget.db.addStudent(
            row['Student Name']!,
            email,
            vId,
            phone: row['Mobile Number'],
            rollNumber: row['Roll Number'],
            dob: row['Date of Birth'],
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully imported ${_parsedRows.length} ${widget.importType}s!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true); // Return true to indicate reload is needed
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving import: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.importType == 'vehicle'
        ? 'Bulk Import Vehicles'
        : widget.importType == 'driver'
        ? 'Bulk Import Drivers'
        : 'Bulk Import Students';

    final bool hasData = _parsedRows.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (hasData)
            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _saveImport,
                    icon: const Icon(
                      Icons.cloud_upload_rounded,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'Save Data',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Requirements Banner Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Spreadsheet Format Guidelines',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your Excel/CSV sheet MUST contain columns with these exact headers. Order does not matter. Use commas or tabs as delimiters.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _requiredHeaders.map((header) {
                              return Chip(
                                label: Text(
                                  header,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: AppColors.primaryLight
                                    .withOpacity(0.4),
                                labelStyle: const TextStyle(
                                  color: AppColors.primary,
                                ),
                                side: BorderSide.none,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // File Picker / paste section
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Dashed File Upload Widget
                          InkWell(
                            onTap: _uploadFile,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 36,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                  style: BorderStyle.solid,
                                  width: 1.5,
                                ),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.cloud_upload_rounded,
                                    color: AppColors.primary,
                                    size: 48,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Upload Spreadsheet (.csv / .xlsx)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Supports exports directly from Microsoft Excel or Google Sheets',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Or Paste CSV Content Below:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _csvController.text = _sampleCsv;
                                  });
                                  _validateData();
                                },
                                child: const Text(
                                  'Load Sample Data',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _csvController,
                            maxLines: 8,
                            onChanged: (_) => _validateData(),
                            decoration: InputDecoration(
                              hintText: '${_requiredHeaders.join(', ')}...',
                              border: const OutlineInputBorder(),
                              fillColor: Colors.white,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Validation & Preview section
                  if (_validationMessage.isNotEmpty) ...[
                    Text(
                      _validationMessage,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: hasData ? AppColors.success : AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (hasData) ...[
                    const Text(
                      'Preview Extracted Data',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      color: Colors.white,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _parsedRows.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final row = _parsedRows[index];
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryLight,
                                radius: 16,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                row[_requiredHeaders[0]] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                _requiredHeaders
                                    .skip(1)
                                    .map((h) => '$h: ${row[h] ?? ""}')
                                    .join(' • '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            onPressed: _saveImport,
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text('Confirm and Save All Records'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                    const SizedBox(height: 48),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLimitExceededDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 28,
              ),
              SizedBox(width: 8),
              Text(
                'Limit Reached',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          content: Text(
            'Importing these records will exceed your vehicle limit! Free Trial organizations are limited to 25 vehicles '
            '(current fleet: ${widget.fleet.length}, attempting to import: ${_parsedRows.length}). '
            'Please upgrade your subscription by contacting us to add more buses.',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showContactSupportInfo();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Contact Support'),
            ),
          ],
        );
      },
    );
  }

  void _showContactSupportInfo() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: const Text(
            'Upgrade Plan',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To upgrade your subscription, please get in touch with our enterprise support team:',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'support@mavio.io',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '+1 (800) 555-0199',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
