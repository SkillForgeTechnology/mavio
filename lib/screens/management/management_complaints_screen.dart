import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/toast_utils.dart';
import '../../models/models.dart';

class ManagementComplaintsScreen extends StatefulWidget {
  final String orgId;
  final String orgName;

  const ManagementComplaintsScreen({
    super.key,
    required this.orgId,
    this.orgName = 'Mavio Network',
  });

  @override
  State<ManagementComplaintsScreen> createState() => _ManagementComplaintsScreenState();
}

class _ManagementComplaintsScreenState extends State<ManagementComplaintsScreen> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = true;
  List<MavioComplaint> _complaints = [];
  String _selectedFilter = 'ALL'; // 'ALL', 'OPEN', 'IN_PROGRESS', 'RESOLVED'

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    setState(() => _isLoading = true);
    try {
      final list = await _db.getOrganizationComplaints(widget.orgId);
      if (mounted) {
        setState(() {
          _complaints = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.show(context, "Error fetching complaints: $e", isError: true);
      }
    }
  }

  List<MavioComplaint> get _filteredComplaints {
    if (_selectedFilter == 'ALL') return _complaints;
    return _complaints.where((c) {
      if (_selectedFilter == 'OPEN') {
        return c.status.toUpperCase() == 'OPEN';
      } else if (_selectedFilter == 'IN_PROGRESS') {
        return c.status.toUpperCase() == 'IN_PROGRESS';
      } else if (_selectedFilter == 'RESOLVED') {
        return c.status.toUpperCase() == 'RESOLVED' || c.status.toUpperCase() == 'CLOSED';
      }
      return true;
    }).toList();
  }

  int get _openCount =>
      _complaints.where((c) => c.status.toUpperCase() == 'OPEN').length;
  int get _inProgressCount =>
      _complaints.where((c) => c.status.toUpperCase() == 'IN_PROGRESS').length;
  int get _resolvedCount =>
      _complaints.where((c) => c.status.toUpperCase() == 'RESOLVED' || c.status.toUpperCase() == 'CLOSED').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Helpdesk & Grievances',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              '${widget.orgName} • Anonymous Student Tickets',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh',
            onPressed: _loadComplaints,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Privacy Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFEFF6FF),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFF2563EB), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Student Anonymous Privacy Active: Personal identity & roll numbers are kept anonymous.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1E40AF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Status Filter Tabs & Summary Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All (${_complaints.length})', AppColors.primary),
                  const SizedBox(width: 8),
                  _buildFilterChip('OPEN', 'Open ($_openCount)', const Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  _buildFilterChip('IN_PROGRESS', 'In Progress ($_inProgressCount)', const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  _buildFilterChip('RESOLVED', 'Resolved ($_resolvedCount)', const Color(0xFF16A34A)),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),

          // Ticket List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredComplaints.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadComplaints,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredComplaints.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final complaint = _filteredComplaints[index];
                            return _buildManagementComplaintCard(complaint);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, Color accentColor) {
    final isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : accentColor.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : accentColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
              child: const Icon(Icons.inbox_rounded, size: 54, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'ALL'
                  ? 'No Complaints Found'
                  : 'No ${_selectedFilter.replaceAll('_', ' ')} Complaints',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Submitted student grievances will appear here for review and resolution.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementComplaintCard(MavioComplaint c) {
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
            color: Colors.black.withOpacity(0.03),
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
            // Top row: Category, Anonymous ID & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Ticket #${c.id.substring(0, c.id.length > 8 ? 8 : c.id.length).toUpperCase()}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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

            // Subject / Title
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

            // Bus & Driver Info Card (strictly NO student details)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_bus_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.busName} (${c.busRegNumber})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Assigned Driver: ${c.driverName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Attached Proof Thumbnail if present
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
                      Icon(Icons.photo_library_rounded, size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'View Student Proof Attachment',
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

            // Admin Notes if present
            if (c.adminNotes != null && c.adminNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.comment_rounded, size: 14, color: Color(0xFF16A34A)),
                        SizedBox(width: 6),
                        Text(
                          'Your Resolution Response:',
                          style: TextStyle(
                            fontSize: 11,
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
                        fontSize: 12,
                        color: Color(0xFF14532D),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 10),

            // Bottom Actions: Timestamp & "Update Status & Reply" Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(c.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showUpdateStatusDialog(c),
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Update Ticket / Reply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateStatusDialog(MavioComplaint c) {
    String selectedStatus = c.status.toUpperCase();
    final noteCtrl = TextEditingController(text: c.adminNotes ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 24),
                  SizedBox(width: 10),
                  Text('Update Ticket Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Change Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'OPEN', child: Text('OPEN (Pending)')),
                        DropdownMenuItem(value: 'IN_PROGRESS', child: Text('IN PROGRESS (Under Investigation)')),
                        DropdownMenuItem(value: 'RESOLVED', child: Text('RESOLVED (Action Taken / Closed)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedStatus = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Resolution Response Note to Student:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'e.g. Warning issued to driver / Route schedule updated...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This response will be visible on the student ticket tracking tab anonymously.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          try {
                            await _db.updateComplaintStatus(
                              complaintId: c.id,
                              newStatus: selectedStatus,
                              adminNotes: noteCtrl.text.trim(),
                            );
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              AppToast.show(context, 'Ticket status updated successfully');
                              _loadComplaints();
                            }
                          } catch (e) {
                            if (mounted) {
                              setDialogState(() => isSaving = false);
                              AppToast.show(context, 'Error updating ticket: $e', isError: true);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save & Reply'),
                ),
              ],
            );
          },
        );
      },
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
