import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/shared.dart';
import 'account_dashboard.dart';

enum _BadgeFilter {
  all('Semua'),
  earned('Diperoleh'),
  inProgress('Dalam Progres');

  const _BadgeFilter(this.label);
  final String label;
}

class BadgeCollection extends StatefulWidget {
  const BadgeCollection({super.key, required this.load});
  final Future<List<Map<String, dynamic>>> Function() load;

  @override
  State<BadgeCollection> createState() => _BadgeCollectionState();
}

class _BadgeCollectionState extends State<BadgeCollection> {
  late Future<List<Map<String, dynamic>>> _result = widget.load();
  _BadgeFilter _filter = _BadgeFilter.all;

  Future<void> _reload() async {
    final result = widget.load();
    setState(() => _result = result);
    try {
      await result;
    } catch (_) {
      // The collection renders the failure with a retry action.
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _result,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return PortalList(
          children: [
            AppPanel(
              child: Column(
                children: [
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _reload,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          ],
        );
      }
      final badges = (snapshot.data ?? []).map(_Badge.new).toList();
      final earned = badges.where((badge) => badge.earned).length;
      final visible = badges.where(
        (badge) => switch (_filter) {
          _BadgeFilter.all => true,
          _BadgeFilter.earned => badge.earned,
          _BadgeFilter.inProgress => !badge.earned,
        },
      );
      return RefreshIndicator(
        onRefresh: _reload,
        child: PortalList(
          children: [
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const PortalIcon(Icons.workspace_premium_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ringkasan Koleksi',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '$earned dari ${badges.length} level diperoleh',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(
                    value: badges.isEmpty ? 0 : earned / badges.length,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: portalSoft,
                    color: portalNavy,
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 7,
              runSpacing: 4,
              children: [
                for (final filter in _BadgeFilter.values)
                  ChoiceChip(
                    label: Text(filter.label),
                    selected: _filter == filter,
                    showCheckmark: false,
                    selectedColor: navy,
                    labelStyle: TextStyle(
                      color: _filter == filter ? Colors.white : navy,
                    ),
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
              ],
            ),
            if (visible.isEmpty)
              AppPanel(
                child: Text(
                  badges.isEmpty
                      ? 'Belum ada badge untuk ditampilkan.'
                      : _filter == _BadgeFilter.earned
                      ? 'Belum ada badge yang diperoleh.'
                      : 'Belum ada badge dalam progres.',
                ),
              ),
            if (visible.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns =
                      constraints.maxWidth >= 314 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 19;
                  final width = twoColumns
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final badge in visible)
                        SizedBox(
                          width: width,
                          child: _BadgeCard(badge: badge),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}

class _Badge {
  _Badge(Map<String, dynamic> row)
    : title = '${row['badge']} · ${row['nama']}',
      level = '${row['nama']}',
      description = row['deskripsi'] as String?,
      earned = row['diperoleh'] == true,
      pending = row['sementara'] == true,
      earnedAt = DateTime.tryParse(row['waktu_diperoleh']?.toString() ?? ''),
      progress = (row['progress'] as num?) ?? 0,
      target = (row['target'] as num?) ?? 0;

  final String title, level;
  final String? description;
  final DateTime? earnedAt;
  final bool earned, pending;
  final num progress, target;

  String get status => earned ? 'Diperoleh' : 'Dalam Progres';
  String get progressText =>
      '$progress / $target${pending ? ' · Progres sementara' : ''}';
  double get fraction => target > 0 ? (progress / target).clamp(0.0, 1.0) : 0;
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});
  final _Badge badge;

  @override
  Widget build(BuildContext context) {
    final icon = badge.earned
        ? Icons.emoji_events_outlined
        : Icons.workspace_premium_outlined;
    final indicator = LinearProgressIndicator(
      value: badge.fraction,
      minHeight: 6,
      borderRadius: BorderRadius.circular(8),
      backgroundColor: portalSoft,
      color: portalTeal,
    );
    return Card(
      color: Colors.white,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: Color(0xFFE7EDF5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showBadge(context, icon),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _BadgeStatus(badge: badge),
              ),
              const SizedBox(height: 10),
              PortalIcon(icon),
              const SizedBox(height: 9),
              Text(
                badge.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!badge.earned) ...[
                const SizedBox(height: 10),
                indicator,
                const SizedBox(height: 6),
                Text(badge.progressText, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showBadge(BuildContext context, IconData icon) => showDetails(
    context,
    title: 'Detail Badge',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: PortalIcon(icon)),
        const SizedBox(height: 10),
        Text(
          badge.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Center(child: _BadgeStatus(badge: badge)),
        const SizedBox(height: 16),
        AppPanel(
          color: portalSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Level: ${badge.level}'),
              if (badge.earnedAt case final date?)
                Text(
                  'Tanggal diperoleh: ${MaterialLocalizations.of(context).formatMediumDate(date.toLocal())}',
                ),
              if (!badge.earned) Text('Progres: ${badge.progressText}'),
            ],
          ),
        ),
        if (badge.description?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          Text(badge.description!),
        ],
      ],
    ),
  );
}

class _BadgeStatus extends StatelessWidget {
  const _BadgeStatus({required this.badge});
  final _Badge badge;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: badge.earned ? const Color(0xFFD2F6E7) : portalSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      badge.status,
      style: TextStyle(
        color: badge.earned ? const Color(0xFF0A5B43) : navy,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    ),
  );
}
