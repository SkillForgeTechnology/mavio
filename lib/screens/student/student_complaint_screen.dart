import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/toast_utils.dart';
import '../../models/models.dart';

class StudentComplaintScreen extends StatefulWidget {
  final MavioProfile profile;
  final MavioVehicle? vehicle;
  final String driverName;

  const StudentComplaintScreen({
    super.key,
    required this.profile,
    this.vehicle,
    this.driverName = 'Not Assigned',
  });

  @override
  State<StudentComplaintScreen> createState() => _StudentComplaintScreenState();
}

class _StudentComplaintScreenState extends State<StudentComplaintScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _db = SupabaseService();

  // Form State
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _busNameController;
  late TextEditingController _busRegController;
  late TextEditingController _driverNameController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedCategory = 'Driver Behavior';
  final List<String> _categories = [
    'Driver Behavior',
    'Bus Timing & Delay',
    'Bus Condition & Cleanliness',
    'Route & Stoppage Issue',
    'Overcrowding / Rash Driving',
    'Emergency / Safety',
    'Other Issue',
  ];

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isPickingImage = false;
  bool _isSubmitting = false;

  // My Tickets State
  List<MavioComplaint> _myComplaints = [];
  bool _isLoadingComplaints = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _busNameController = TextEditingController(
      text: widget.vehicle?.name ?? (widget.vehicle != null ? 'Bus #${widget.vehicle!.regNumber}' : 'Not Assigned'),
    );
    _busRegController = TextEditingController(
      text: widget.vehicle?.regNumber ?? 'N/A',
    );
    _driverNameController = TextEditingController(
      text: widget.driverName.isNotEmpty ? widget.driverName : 'Not Assigned',
    );

    _loadMyComplaints();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _busNameController.dispose();
    _busRegController.dispose();
    _driverNameController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMyComplaints() async {
    setState(() => _isLoadingComplaints = true);
    try {
      final list = await _db.getStudentComplaints(widget.profile.id);
      if (mounted) {
        setState(() {
          _myComplaints = list;
          _isLoadingComplaints = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingComplaints = false);
      }
    }
  }

  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes = file.bytes;

        if (bytes == null && file.path != null && !kIsWeb) {
          final ioFile = File(file.path!);
          if (await ioFile.exists()) {
            bytes = await ioFile.readAsBytes();
          }
        }

        if (bytes != null) {
          // Limit to max 3MB for base64 storage safety
          if (bytes.lengthInBytes > 3 * 1024 * 1024) {
            if (mounted) {
              AppToast.show(context, "Image is larger than 3MB. Please choose a smaller photo.");
            }
            return;
          }

          if (mounted) {
            setState(() {
              _selectedImageBytes = bytes;
              _selectedImageName = file.name;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, "Failed to pick image: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
    });
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    String? base64Image;
    if (_selectedImageBytes != null) {
      base64Image = 'data:image/jpeg;base64,${base64Encode(_selectedImageBytes!)}';
    }

    try {
      await _db.submitComplaint(
        orgId: widget.profile.orgId,
        studentId: widget.profile.id,
        busId: widget.vehicle?.id,
        busName: _busNameController.text.trim().isNotEmpty
            ? _busNameController.text.trim()
            : (widget.vehicle?.name ?? 'General Bus'),
        busRegNumber: _busRegController.text.trim().isNotEmpty
            ? _busRegController.text.trim()
            : 'N/A',
        driverName: _driverNameController.text.trim().isNotEmpty
            ? _driverNameController.text.trim()
            : 'Not Assigned',
        category: _selectedCategory,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageProof: base64Image,
      );

      if (mounted) {
        AppToast.show(context, "Complaint submitted successfully. You can track status in 'My Tickets'.");
        _titleController.clear();
        _descriptionController.clear();
        _removeImage();
        setState(() => _isSubmitting = false);
        _loadMyComplaints();
        _tabController.animateTo(1); // Switch to My Tickets tab
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppToast.show(context, "Error submitting complaint: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Grievances & Helpdesk',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(
              icon: Icon(Icons.edit_note_rounded, size: 20),
              text: "Register Complaint",
            ),
            Tab(
              icon: Icon(Icons.history_rounded, size: 20),
              text: "My Tickets",
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRegisterFormTab(),
          _buildMyTicketsTab(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: REGISTER COMPLAINT FORM
  // ==========================================
  Widget _buildRegisterFormTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.08),
                    AppColors.primaryLight.withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.privacy_tip_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anonymous Submission',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Your student identity (Name & Roll Number) is kept strictly hidden from management. Only bus & complaint details are forwarded.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section: Bus & Driver Details (Auto-filled)
            const Text(
              'Assigned Vehicle & Driver',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight, width: 1.5),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _busNameController,
                    decoration: InputDecoration(
                      labelText: 'Bus Name / Route',
                      prefixIcon: const Icon(Icons.directions_bus_rounded, color: AppColors.primary, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Please enter bus name' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _busRegController,
                          decoration: InputDecoration(
                            labelText: 'Registration No.',
                            prefixIcon: const Icon(Icons.pin_drop_rounded, color: AppColors.primary, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _driverNameController,
                          decoration: InputDecoration(
                            labelText: 'Driver Name',
                            prefixIcon: const Icon(Icons.person_pin_rounded, color: AppColors.primary, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section: Category Selection
            const Text(
              'Issue Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.borderLight,
                      width: 1.2,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Section: Complaint Details
            const Text(
              'Complaint Details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight, width: 1.5),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Subject / Short Summary *',
                      hintText: 'e.g. Bus arrived 30 mins late without update',
                      prefixIcon: const Icon(Icons.title_rounded, color: AppColors.primary, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Please enter a summary/subject' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Detailed Explanation *',
                      hintText: 'Explain the issue with exact location, time, and circumstances...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    validator: (val) =>
                        val == null || val.trim().length < 10 ? 'Please explain in at least 10 characters' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section: Proof Submission (Optional Image)
            const Text(
              'Attach Proof / Photo (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight, width: 1.5),
              ),
              child: Column(
                children: [
                  if (_isPickingImage) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            strokeWidth: 2.5,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Loading & preparing image...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_selectedImageBytes != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _selectedImageBytes!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _removeImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _selectedImageName ?? 'Photo selected',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 28),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Tap to upload screenshot or photo proof',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'PNG, JPG up to 3MB',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitComplaint,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Submitting...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Submit Grievance',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: MY TICKETS / COMPLAINTS LIST
  // ==========================================
  Widget _buildMyTicketsTab() {
    if (_isLoadingComplaints) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myComplaints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded, size: 54, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Complaints Registered',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You have not submitted any complaints yet. All reported issues and their live resolution status will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Register New Complaint'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyComplaints,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _myComplaints.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final complaint = _myComplaints[index];
          return _buildComplaintCard(complaint);
        },
      ),
    );
  }

  Widget _buildComplaintCard(MavioComplaint c) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (c.status.toUpperCase()) {
      case 'IN_PROGRESS':
        statusColor = const Color(0xFF2563EB);
        statusIcon = Icons.pending_actions_rounded;
        statusLabel = 'IN PROGRESS';
        break;
      case 'RESOLVED':
      case 'CLOSED':
        statusColor = const Color(0xFF16A34A);
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'RESOLVED';
        break;
      default:
        statusColor = const Color(0xFFD97706);
        statusIcon = Icons.error_outline_rounded;
        statusLabel = 'OPEN';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Category Pill & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    c.category,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              c.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            // Description
            Text(
              c.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Bus & Driver Meta
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_bus_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${c.busName} (${c.busRegNumber}) • Driver: ${c.driverName}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Image Proof Thumbnail if attached
            if (c.imageProof != null && c.imageProof!.isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _showImageDialog(c.imageProof!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'View Attached Proof Image',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Admin Resolution Note (if management replied)
            if (c.adminNotes != null && c.adminNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.admin_panel_settings_rounded, size: 16, color: Color(0xFF16A34A)),
                        SizedBox(width: 6),
                        Text(
                          'Management Response',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.adminNotes!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF14532D),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            // Timestamp
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Submitted: ${DateFormat('dd MMM yyyy, hh:mm a').format(c.createdAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageDialog(String base64OrUrl) {
    Uint8List? bytes;
    try {
      if (base64OrUrl.startsWith('data:image')) {
        final commaIdx = base64OrUrl.indexOf(',');
        final data = base64OrUrl.substring(commaIdx + 1);
        bytes = base64Decode(data);
      } else if (!base64OrUrl.startsWith('http')) {
        bytes = base64Decode(base64OrUrl);
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: bytes != null
                    ? Image.memory(bytes, fit: BoxFit.contain)
                    : Image.network(base64OrUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
