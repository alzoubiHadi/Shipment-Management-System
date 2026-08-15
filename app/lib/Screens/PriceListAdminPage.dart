import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../API/PriceListService.dart';
import '../API/config.dart';
import '../models/PriceListEntry.dart';

/// Finance Admin: manage the central price matrix (UC-33). Mirrors the
/// backend's CSV-based workflow — Export gives the full grid (destination x
/// truck type, blank where still unpriced) as CSV text to copy into Excel;
/// Import uploads the edited CSV back. The list below is a read-only view of
/// whatever is currently priced, for a quick sanity check without leaving
/// the app.
class PriceListAdminPage extends StatefulWidget {
  const PriceListAdminPage({super.key});

  @override
  State<PriceListAdminPage> createState() => _PriceListAdminPageState();
}

class _PriceListAdminPageState extends State<PriceListAdminPage> {
  final _service = PriceListService();
  late Future<List<PriceListEntry>> _entriesFuture;
  bool _busy = false;

  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _refresh();
    _searchController.addListener(() {
      setState(() => _search = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() => _entriesFuture = _service.fetchEntries());
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final csv = await _service.exportCsv();
      if (!mounted) return;
      setState(() => _busy = false);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Price list CSV',
              style: TextStyle(color: AppColors.cream)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(
                csv,
                style: const TextStyle(
                    color: AppColors.cream, fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csv));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              child: const Text('Copy', style: TextStyle(color: AppColors.gold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppColors.muted)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );

    if (picked == null || picked.files.single.bytes == null) return;

    setState(() => _busy = true);
    final result = await _service.importCsv(
      fileBytes: picked.files.single.bytes!,
      fileName: picked.files.single.name,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    final skipped = result['skipped'] as List<String>;

    if (result['success'] == true) {
      _refresh();
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          result['success'] == true ? 'Import complete' : 'Import failed',
          style: const TextStyle(color: AppColors.cream),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(result['message']?.toString() ?? '',
                    style: const TextStyle(color: AppColors.cream)),
                if (skipped.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text('Skipped rows:',
                      style: TextStyle(
                          color: AppColors.error, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  for (final s in skipped)
                    Text('• $s',
                        style:
                            const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  List<PriceListEntry> _filter(List<PriceListEntry> entries) {
    if (_search.isEmpty) return entries;
    return entries
        .where((e) =>
            e.destination.toLowerCase().contains(_search) ||
            e.truckType.toLowerCase().contains(_search))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.cream),
        title: const Text('Price List', style: TextStyle(color: AppColors.cream)),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () async => _refresh(),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _export,
                            icon: const Icon(Icons.download_outlined,
                                color: AppColors.gold, size: 18),
                            label: const Text('Export CSV',
                                style: TextStyle(color: AppColors.gold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _import,
                            icon: const Icon(Icons.upload_outlined,
                                color: AppColors.gold, size: 18),
                            label: const Text('Import CSV',
                                style: TextStyle(color: AppColors.gold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppColors.cream),
                      decoration: InputDecoration(
                        hintText: 'Search by destination or truck type...',
                        hintStyle: const TextStyle(color: AppColors.muted),
                        prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: FutureBuilder<List<PriceListEntry>>(
                    future: _entriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(
                            child: CircularProgressIndicator(color: AppColors.gold),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Could not load price list: ${snapshot.error}',
                            style: const TextStyle(color: AppColors.error),
                          ),
                        );
                      }

                      final entries = _filter(snapshot.data ?? []);

                      if (entries.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: Text('No priced rows match',
                                style: TextStyle(color: AppColors.muted)),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        child: Column(
                          children: [
                            for (int i = 0; i < entries.length; i++) ...[
                              if (i > 0) const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border, width: 0.5),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(entries[i].destination,
                                              style: const TextStyle(
                                                  color: AppColors.cream,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Text(entries[i].truckType,
                                              style: const TextStyle(
                                                  color: AppColors.muted, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${entries[i].basePrice.toStringAsFixed(0)} AED',
                                      style: const TextStyle(
                                          color: AppColors.gold,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_busy)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            ),
        ],
      ),
    );
  }
}
