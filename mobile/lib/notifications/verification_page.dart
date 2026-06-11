import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/app_strings.dart';
import '../models/app_notification.dart';
import '../theme_controller.dart';
import '../tree/tree_page.dart';
import '../widgets/glass.dart';
import '../widgets/top_toast.dart';

/// Admin-only verification screen — the enhanced replacement for the old web
/// "Unpublished Additions" table. Lists every pending (private) person and lets
/// the admin filter by contributor, by creation date range, and by name, then
/// batch-publish either an explicit multi-selection or everything currently
/// matching the filters.
class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key, required this.auth, required this.theme});

  final AuthService auth;
  final ThemeController theme;

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  late Future<List<PendingAddition>> _future;
  List<PendingAddition> _all = const [];

  // Filters.
  String _search = '';
  int? _contributorId; // null = any contributor
  DateTimeRange? _dateRange;

  // Explicit multi-selection (person ids). Empty = act on the whole filtered set.
  final Set<int> _selected = {};
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PendingAddition>> _load() async {
    final items = await widget.auth.api.pendingAdditions();
    _all = items;
    return items;
  }

  Future<void> _reload() async {
    _selected.clear();
    setState(() => _future = _load());
    await _future;
    if (mounted) setState(() {});
  }

  /// All distinct non-staff contributors across the pending additions, for the
  /// "filter by user" dropdown.
  List<PendingEditor> get _contributors {
    final byId = <int, PendingEditor>{};
    for (final p in _all) {
      for (final e in p.contributors) {
        byId.putIfAbsent(e.id, () => e);
      }
    }
    final list = byId.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<PendingAddition> get _filtered {
    return _all.where((p) {
      if (_search.isNotEmpty &&
          !p.name.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      if (_contributorId != null &&
          !p.contributors.any((e) => e.id == _contributorId)) {
        return false;
      }
      if (_dateRange != null) {
        final d = p.creationTime;
        // Inclusive end-of-day.
        final end = DateTime(_dateRange!.end.year, _dateRange!.end.month,
            _dateRange!.end.day, 23, 59, 59);
        if (d.isBefore(_dateRange!.start) || d.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (range != null) setState(() => _dateRange = range);
  }

  Future<void> _openPerson(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TreePage(
          auth: widget.auth,
          theme: widget.theme,
          initialPersonId: id,
        ),
      ),
    );
    _reload();
  }

  /// Ids the publish action will affect: the explicit selection if any,
  /// otherwise the entire filtered set.
  List<int> get _targetIds =>
      _selected.isNotEmpty ? _selected.toList() : _filtered.map((p) => p.id).toList();

  Future<void> _publish() async {
    final t = AppStrings.of(context);
    final ids = _targetIds;
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.verifyConfirmTitle),
        content: Text(t.verifyConfirmBody(ids.length)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(t.verifyAction)),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _publishing = true);
    try {
      final result = await widget.auth.api.batchPublish(ids);
      if (mounted) {
        showTopToast(context, t.verifyDone(result.published));
        await _reload();
      }
    } catch (_) {
      if (mounted) showTopToast(context, t.errorConnection);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _toggleSelectAll(List<PendingAddition> filtered) {
    setState(() {
      final allSelected = filtered.every((p) => _selected.contains(p.id));
      if (allSelected) {
        _selected.removeWhere((id) => filtered.any((p) => p.id == id));
      } else {
        _selected.addAll(filtered.map((p) => p.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.verificationTitle)),
      body: FutureBuilder<List<PendingAddition>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.errorConnection, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _reload, child: Text(t.retry)),
                  ],
                ),
              ),
            );
          }
          // Drop a contributor filter that no longer exists (e.g. all of that
          // user's additions were just published), so the dropdown's value
          // always matches one of its items.
          if (_contributorId != null &&
              !_contributors.any((e) => e.id == _contributorId)) {
            _contributorId = null;
          }
          final filtered = _filtered;
          return Column(
            children: [
              _filterBar(t),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _all.isEmpty ? t.verificationEmpty : t.verificationNoMatch,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _additionTile(t, filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(t),
    );
  }

  Widget _filterBar(AppStrings t) {
    final contributors = _contributors;
    final filtered = _filtered;
    final allSelected =
        filtered.isNotEmpty && filtered.every((p) => _selected.contains(p.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: t.verifySearchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(isDense: true),
                  // A directly value-controlled DropdownButton (not a
                  // DropdownButtonFormField) so its displayed value always
                  // tracks _contributorId — including being reset to null when a
                  // contributor disappears after their additions are published.
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _contributorId,
                      isExpanded: true,
                      isDense: true,
                      items: [
                        DropdownMenuItem<int?>(value: null, child: Text(t.verifyAnyUser)),
                        ...contributors.map(
                          (e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.name)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _contributorId = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: t.verifyDateFilter,
                icon: Icon(_dateRange == null
                    ? Icons.calendar_today_outlined
                    : Icons.event_available),
                onPressed: _pickDateRange,
              ),
              if (_dateRange != null || _contributorId != null || _search.isNotEmpty)
                IconButton(
                  tooltip: t.verifyClearFilters,
                  icon: const Icon(Icons.filter_alt_off),
                  onPressed: () => setState(() {
                    _dateRange = null;
                    _contributorId = null;
                    _search = '';
                  }),
                ),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: filtered.isEmpty ? null : () => _toggleSelectAll(filtered),
                icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                label: Text(allSelected ? t.verifyDeselectAll : t.verifySelectAll),
              ),
              const Spacer(),
              Text(
                t.verifyCount(filtered.length),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _additionTile(AppStrings t, PendingAddition p) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected.contains(p.id);
    final contributors = p.contributors;
    return GlassPanel(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: CheckboxListTile(
        value: selected,
        onChanged: (v) => setState(() {
          if (v == true) {
            _selected.add(p.id);
          } else {
            _selected.remove(p.id);
          }
        }),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (contributors.isNotEmpty)
              Text(
                t.verifyBy(contributors.map((e) => e.name).join('، ')),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            Text(
              _formatDate(p.creationTime),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
        secondary: IconButton(
          tooltip: t.verifyOpen,
          icon: const Icon(Icons.open_in_new),
          onPressed: () => _openPerson(p.id),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget? _buildBottomBar(AppStrings t) {
    final ids = _targetIds;
    if (ids.isEmpty) return null;
    final label = _selected.isNotEmpty
        ? t.verifyPublishSelected(ids.length)
        : t.verifyPublishAll(ids.length);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: _publishing ? null : _publish,
          icon: _publishing
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.verified),
          label: Text(label),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
