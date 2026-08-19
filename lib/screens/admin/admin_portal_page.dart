import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/theme.dart';
import '../../core/services/supabase_service.dart';
import '../../models/models.dart';

class AdminPortalPage extends StatefulWidget {
  const AdminPortalPage({super.key});

  @override
  State<AdminPortalPage> createState() => _AdminPortalPageState();
}

class _AdminPortalPageState extends State<AdminPortalPage> {
  final SupabaseService _db = SupabaseService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<MavioOrganization> _organizations = [];
  List<MavioOrganization> _filteredOrganizations = [];
  bool _isFetchingOrgs = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterOrganizations);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Super-Admin Authentication Flow
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    if (email != 'admin@mavio.com') {
      setState(() => _errorMessage = 'Access denied. Invalid Super-Admin email.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool authSuccess = false;
      // 1. Try Live Supabase Auth if available
      try {
        final client = Supabase.instance.client;
        final response = await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (response.session != null) {
          authSuccess = true;
        }
      } catch (e) {
        // Fallback to local authentication for mock and initial setups
        if (password == 'admin123' || password == 'admin') {
          authSuccess = true;
        }
      }

      if (authSuccess) {
        setState(() {
          _isLoggedIn = true;
        });
        _loadOrganizations();
      } else {
        setState(() => _errorMessage = 'Incorrect password.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Login failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Load organizations from database/mock service
  Future<void> _loadOrganizations() async {
    setState(() => _isFetchingOrgs = true);
    try {
      final list = await _db.fetchOrganizations();
      setState(() {
        _organizations = list;
        _filteredOrganizations = list;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading organizations: $e')),
      );
    } finally {
      setState(() => _isFetchingOrgs = false);
    }
  }

  // Filter organizations in UI
  void _filterOrganizations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredOrganizations = _organizations.where((org) {
        return org.name.toLowerCase().contains(query) || org.code.toLowerCase().contains(query);
      }).toList();
    });
  }

  // Add Organization Dialog
  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Add Organization', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'College/Organization Name',
                  hintText: 'e.g. Harvard University',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Unique Organization Code',
                  hintText: 'e.g. HARV12',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final code = codeCtrl.text.trim().toUpperCase();
                      if (name.isEmpty || code.isEmpty) return;

                      setModalState(() => isSaving = true);
                      final newOrg = await _db.createOrganization(name, code);
                      if (newOrg != null) {
                        Navigator.pop(ctx);
                        _loadOrganizations();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Organization added successfully!')),
                        );
                      } else {
                        setModalState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to add organization. Code might be taken.')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Organization Dialog
  void _showEditDialog(MavioOrganization org) {
    final nameCtrl = TextEditingController(text: org.name);
    final codeCtrl = TextEditingController(text: org.code);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Edit Organization', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'College Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Organization Code'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final code = codeCtrl.text.trim().toUpperCase();
                      if (name.isEmpty || code.isEmpty) return;

                      setModalState(() => isSaving = true);
                      final updated = await _db.updateOrganization(org.id, name, code);
                      if (updated != null) {
                        Navigator.pop(ctx);
                        _loadOrganizations();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Organization updated successfully!')),
                        );
                      } else {
                        setModalState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to update organization.')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  // Delete Organization Confirmation
  void _confirmDelete(MavioOrganization org) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Confirm Deletion', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${org.name} (${org.code})?\nThis action is irreversible and might affect registered profiles.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _db.deleteOrganization(org.id);
              if (success) {
                _loadOrganizations();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Organization deleted successfully.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to delete organization.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F11), // Dark space background
      body: Stack(
        children: [
          // Background Mesh Orbs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF8A65).withOpacity(0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Main View switcher
          Positioned.fill(
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _isLoggedIn ? _buildConsole() : _buildLoginCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Super-Admin Glassmorphic Login Screen
  Widget _buildLoginCard() {
    return Center(
      child: Container(
        width: 420,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1F).withOpacity(0.7),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand Logo
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.1),
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, size: 40, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Super-Admin Access',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Log in to manage network organizations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 32),

            // Email Field
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF26262B),
                prefixIcon: const Icon(Icons.mail_outline_rounded, color: Colors.white54),
                hintText: 'admin@mavio.com',
                hintStyle: const TextStyle(color: Colors.white24),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Password Field
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF26262B),
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white54),
                hintText: 'Password',
                hintStyle: const TextStyle(color: Colors.white24),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Error display
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.2)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),

            // Login Button
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Authenticate Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Super-Admin Console dashboard
  Widget _buildConsole() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MAVIO',
                        style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                      Text(
                        'Super-Admin Console',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoggedIn = false;
                    _emailController.clear();
                    _passwordController.clear();
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withOpacity(0.08)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Logout'),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Search & Control Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1B1B1F),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                    hintText: 'Search by organization name or code...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 54),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Organization', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Total Stats Indicator
          Row(
            children: [
              const Text('Active Networks:', style: TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_organizations.length}',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Organization Grid List
          Expanded(
            child: _isFetchingOrgs
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredOrganizations.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _filteredOrganizations.length,
                        itemBuilder: (context, index) {
                          final org = _filteredOrganizations[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B1B1F),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.03)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      org.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.06),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            org.code,
                                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'ID: ${org.id}',
                                          style: const TextStyle(color: Colors.white24, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                                      tooltip: 'Edit Organization',
                                      onPressed: () => _showEditDialog(org),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                      tooltip: 'Delete Organization',
                                      onPressed: () => _confirmDelete(org),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.domain_disabled_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('No Organizations Found', style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Create a new organization network to begin management.', style: TextStyle(color: Colors.white24, fontSize: 13)),
        ],
      ),
    );
  }
}
