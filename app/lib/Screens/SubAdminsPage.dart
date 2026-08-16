import 'package:flutter/material.dart';

import '../API/AdminService.dart';
import '../API/config.dart';
import '../models/SubAdmin.dart';

/// UC-6: Super Admin creates and manages sub-admin accounts, each holding
/// one or more composable permission groups (finance, crm, trainer,
/// technical_check, ...). Reached from Reports ← Sub-Admins.
class SubAdminsPage extends StatefulWidget {
  const SubAdminsPage({super.key});

  @override
  State<SubAdminsPage> createState() => _SubAdminsPageState();
}

class _SubAdminsPageState extends State<SubAdminsPage> {
  final _service = AdminService();
  late Future<List<SubAdmin>> _adminsFuture;
  List<PermissionGroup> _groups = [];
  bool _groupsLoaded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadGroups();
  }

  void _refresh() => setState(() => _adminsFuture = _service.fetchSubAdmins());

  Future<void> _loadGroups() async {
    try {
      final groups = await _service.fetchPermissionGroups();
      if (mounted) setState(() {
        _groups = groups;
        _groupsLoaded = true;
      });
    } catch (_) {
      // Create/edit dialogs will just show no permission checkboxes; the
      // list itself still works.
    }
  }

  Future<void> _showTemporaryPassword(String name, String password) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Temporary Password', style: TextStyle(color: AppColors.cream)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('For $name — share this now, it will not be shown again:',
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            SelectableText(
              password,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateOrEdit({SubAdmin? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final selected = <String>{...(existing?.permissionKeys ?? const [])};
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? 'Create Sub-Admin' : 'Edit Permissions',
                    style: const TextStyle(
                        color: AppColors.cream, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  if (existing == null) ...[
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: AppColors.cream),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      style: const TextStyle(color: AppColors.cream),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('Permission groups',
                      style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  if (!_groupsLoaded)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _groups.map((g) {
                        final isSelected = selected.contains(g.key);
                        return FilterChip(
                          label: Text(g.label),
                          selected: isSelected,
                          selectedColor: AppColors.gold.withOpacity(0.2),
                          backgroundColor: AppColors.bg,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.gold : AppColors.muted,
                            fontSize: 12,
                          ),
                          side: BorderSide(color: isSelected ? AppColors.gold : AppColors.border),
                          onSelected: (v) => setSheetState(() {
                            if (v) {
                              selected.add(g.key);
                            } else {
                              selected.remove(g.key);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
                      onPressed: saving
                          ? null
                          : () async {
                              if (existing == null &&
                                  (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty)) {
                                return;
                              }
                              if (selected.isEmpty) return;

                              setSheetState(() => saving = true);

                              if (existing == null) {
                                final result = await _service.createSubAdmin(
                                  name: nameCtrl.text.trim(),
                                  email: emailCtrl.text.trim(),
                                  permissionKeys: selected.toList(),
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (result['success'] == true) {
                                  _refresh();
                                  await _showTemporaryPassword(
                                    nameCtrl.text.trim(),
                                    result['temporary_password']?.toString() ?? '',
                                  );
                                } else if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(result['message']?.toString() ?? 'Failed')),
                                  );
                                }
                              } else {
                                final result = await _service.updatePermissions(
                                  adminId: existing.id,
                                  permissionKeys: selected.toList(),
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (result['success'] == true) {
                                  _refresh();
                                } else if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(result['message']?.toString() ?? 'Failed')),
                                  );
                                }
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                            )
                          : Text(existing == null ? 'Create' : 'Save',
                              style: const TextStyle(color: AppColors.bg, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _resetPassword(SubAdmin admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reset Password', style: TextStyle(color: AppColors.cream)),
        content: Text('Issue a new temporary password for ${admin.name}?',
            style: const TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await _service.resetPassword(admin.id);
    if (result['success'] == true) {
      await _showTemporaryPassword(admin.name, result['temporary_password']?.toString() ?? '');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Failed')),
      );
    }
  }

  Future<void> _toggleSuspend(SubAdmin admin) async {
    final suspending = !admin.isSuspended;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(suspending ? 'Suspend Sub-Admin' : 'Reactivate Sub-Admin',
            style: const TextStyle(color: AppColors.cream)),
        content: Text(
          suspending
              ? 'Block ${admin.name} from logging in until reactivated?'
              : 'Allow ${admin.name} to log in again?',
          style: const TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(suspending ? 'Suspend' : 'Reactivate',
                style: TextStyle(color: suspending ? AppColors.error : AppColors.success)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = suspending
        ? await _service.suspendSubAdmin(admin.id)
        : await _service.activateSubAdmin(admin.id);

    if (result['success'] == true) {
      _refresh();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? '')),
      );
    }
  }

  Future<void> _delete(SubAdmin admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Sub-Admin', style: TextStyle(color: AppColors.cream)),
        content: Text('Delete ${admin.name}\'s account? This cannot be undone.',
            style: const TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await _service.deleteSubAdmin(admin.id);
    if (success) {
      _refresh();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete sub-admin')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Sub-Admins', style: TextStyle(color: AppColors.cream)),
        iconTheme: const IconThemeData(color: AppColors.cream),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        onPressed: () => _openCreateOrEdit(),
        child: const Icon(Icons.add, color: AppColors.bg),
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<SubAdmin>>(
          future: _adminsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.gold));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Could not load sub-admins',
                    style: const TextStyle(color: AppColors.error)),
              );
            }

            final admins = snapshot.data ?? [];
            if (admins.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text('No sub-admins yet. Tap + to create one.',
                          style: TextStyle(color: AppColors.muted)),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: admins.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final admin = admins[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(admin.name,
                                    style: const TextStyle(
                                        color: AppColors.cream, fontSize: 14, fontWeight: FontWeight.w600)),
                                Text(admin.email,
                                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (admin.isSuspended)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Suspended',
                                  style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w600)),
                            )
                          else if (admin.mustChangePassword)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('First login pending',
                                  style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: admin.permissionKeys.map((k) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.info.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(k,
                                style: const TextStyle(color: AppColors.info, fontSize: 10, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openCreateOrEdit(existing: admin),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border)),
                              icon: const Icon(Icons.tune, size: 16, color: AppColors.cream),
                              label: const Text('Permissions', style: TextStyle(color: AppColors.cream, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _resetPassword(admin),
                            icon: const Icon(Icons.password, color: AppColors.gold, size: 20),
                            tooltip: 'Reset password',
                          ),
                          IconButton(
                            onPressed: () => _toggleSuspend(admin),
                            icon: Icon(
                              admin.isSuspended ? Icons.play_circle_outline : Icons.pause_circle_outline,
                              color: admin.isSuspended ? AppColors.success : AppColors.error,
                              size: 20,
                            ),
                            tooltip: admin.isSuspended ? 'Reactivate' : 'Suspend',
                          ),
                          IconButton(
                            onPressed: () => _delete(admin),
                            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
