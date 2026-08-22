import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/services/supabase_service.dart';
import '../../models/models.dart';

class OrganizationDetailPage extends StatefulWidget {
  final MavioOrganization organization;

  const OrganizationDetailPage({super.key, required this.organization});

  @override
  State<OrganizationDetailPage> createState() => _OrganizationDetailPageState();
}

class _OrganizationDetailPageState extends State<OrganizationDetailPage>
    with SingleTickerProviderStateMixin {
  final SupabaseService _db = SupabaseService();
  late TabController _tabController;
  bool _isLoading = true;
  List<MavioVehicle> _buses = [];
  List<MavioProfile> _drivers = [];
  List<MavioProfile> _students = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final data = await _db.getOrganizationDetailData(widget.organization.id);
      final busesData = List<MavioVehicle>.from(data['buses']);
      busesData.sort((a, b) => _naturalCompare(a.name, b.name));

      final driversData = List<MavioProfile>.from(data['drivers']);
      driversData.sort((a, b) => _naturalCompare(a.name, b.name));

      final studentsData = List<MavioProfile>.from(data['students']);
      studentsData.sort((a, b) => _naturalCompare(a.name, b.name));

      setState(() {
        _buses = busesData;
        _drivers = driversData;
        _students = studentsData;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _naturalCompare(String a, String b) {
    final regExp = RegExp(r'(\d+)|(\D+)');
    final matchesA = regExp.allMatches(a.toUpperCase()).map((m) => m.group(0)!).toList();
    final matchesB = regExp.allMatches(b.toUpperCase()).map((m) => m.group(0)!).toList();

    for (int i = 0; i < matchesA.length && i < matchesB.length; i++) {
      final strA = matchesA[i];
      final strB = matchesB[i];

      final numA = int.tryParse(strA);
      final numB = int.tryParse(strB);

      if (numA != null && numB != null) {
        final comp = numA.compareTo(numB);
        if (comp != 0) return comp;
      } else {
        final comp = strA.compareTo(strB);
        if (comp != 0) return comp;
      }
    }
    return matchesA.length.compareTo(matchesB.length);
  }

  String _formatIsoDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = widget.organization;

    // Badges Colors
    Color badgeColor = Colors.amber;
    String badgeText = 'Free Trial';
    if (org.subscriptionStatus == 'active') {
      badgeColor = Colors.green;
      badgeText = 'Premium Active';
    } else if (org.subscriptionStatus == 'inactive') {
      badgeColor = AppColors.error;
      badgeText = 'Inactive';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F), // Dark Slate Background
      appBar: AppBar(
        backgroundColor: const Color(0xFF131317),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${org.name} Details',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Organization Summary Header Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF131317),
                    border: Border(
                      bottom: BorderSide(color: Colors.white12, width: 0.8),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primary, AppColors.primary.withOpacity(0.6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              org.name.substring(0, 2).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      org.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        org.code,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Joined on: ${_formatIsoDate(org.createdAt)}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: badgeColor.withOpacity(0.2)),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: Colors.white.withOpacity(0.06)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          _buildHeaderMetaItem(Icons.mail_outline_rounded, org.email ?? 'No email'),
                          _buildHeaderMetaItem(Icons.phone_android_rounded, org.phone ?? 'No phone'),
                          _buildHeaderMetaItem(Icons.pin_drop_outlined, org.address ?? 'No address'),
                        ],
                      ),
                    ],
                  ),
                ),

                // Custom Tabs Navigation
                Container(
                  color: const Color(0xFF131317),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.white54,
                    tabs: [
                      Tab(text: 'Buses (${_buses.length})'),
                      Tab(text: 'Drivers (${_drivers.length})'),
                      Tab(text: 'Students (${_students.length})'),
                    ],
                  ),
                ),

                // Tabs Views Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBusesList(),
                      _buildDriversList(),
                      _buildStudentsList(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white30, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white38, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildBusesList() {
    if (_buses.isEmpty) {
      return _buildEmptyState('No registered buses yet.', Icons.directions_bus_filled_rounded);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _buses.length,
      itemBuilder: (context, index) {
        final bus = _buses[index];
        final bool isOnline = bus.status == 'ONLINE';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131317),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.directions_bus_filled_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bus.regNumber,
                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isOnline ? Colors.green : Colors.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  bus.status,
                  style: TextStyle(
                    color: isOnline ? Colors.green : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDriversList() {
    if (_drivers.isEmpty) {
      return _buildEmptyState('No registered drivers yet.', Icons.person_outline_rounded);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _drivers.length,
      itemBuilder: (context, index) {
        final driver = _drivers[index];

        // Find assigned bus name
        String assignedBusName = "Not Assigned";
        if (driver.assignedVehicleId != null) {
          final bus = _buses.firstWhere(
            (b) => b.id == driver.assignedVehicleId,
            orElse: () => MavioVehicle(id: '', name: 'Assigned Bus', regNumber: '', status: '', orgId: ''),
          );
          if (bus.id.isNotEmpty) {
            assignedBusName = bus.name;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131317),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driver.email,
                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                    if (driver.phone != null && driver.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Phone: ${driver.phone}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ]
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'ROUTE ASSIGNED',
                      style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      assignedBusName,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentsList() {
    if (_students.isEmpty) {
      return _buildEmptyState('No registered students yet.', Icons.school_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];

        // Find assigned bus name
        String assignedBusName = "Not Assigned";
        if (student.assignedVehicleId != null) {
          final bus = _buses.firstWhere(
            (b) => b.id == student.assignedVehicleId,
            orElse: () => MavioVehicle(id: '', name: 'Assigned Bus', regNumber: '', status: '', orgId: ''),
          );
          if (bus.id.isNotEmpty) {
            assignedBusName = bus.name;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131317),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      student.email,
                      style: const TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                    if (student.phone != null && student.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Parent Contact: ${student.phone}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ]
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'BOARDING BUS',
                      style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      assignedBusName,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
