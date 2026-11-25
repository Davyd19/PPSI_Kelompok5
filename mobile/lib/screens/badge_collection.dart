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

  Future<void> _reload() {
    final result = widget.load();
    setState(() => _result = result);
    return result.then((_) {}, onError: (_) {});
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
                    color: PortalTone.of(context).color,
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
      color: PortalTone.of(context).color,
    );
    return Card(
      color: Colors.white,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: line),
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
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFDE68A), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18F59E0B),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.workspace_premium,
                color: Color(0xFFD97706),
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          badge.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F2942),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, size: 13, color: Color(0xFF16A34A)),
                const SizedBox(width: 4),
                Text(
                  badge.earned ? 'Terverifikasi Otomatis' : badge.status,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: const [
                    Text(
                      'Kategori',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kehadiran',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F2942),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Tanggal Diperoleh',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      badge.earnedAt != null
                          ? MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(badge.earnedAt!.toLocal())
                          : (badge.earned ? '10 Feb 2025' : '-'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F2942),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                badge.description?.trim().isNotEmpty ?? false
                    ? badge.description!
                    : 'Pencapaian kehadiran dan prestasi siswa yang terverifikasi resmi oleh pihak sekolah.',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              if (!badge.earned) ...[
                const SizedBox(height: 8),
                Text(
                  'Progres: ${badge.progressText}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2942),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Lencana dibagikan ke profil publik.'),
                    ),
                  );
                },
                icon: const Icon(Icons.share, size: 15),
                label: const Text(
                  'Bagikan Lencana',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
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
      color: badge.earned ? cGreen.$2 : soft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      badge.status,
      style: TextStyle(
        color: badge.earned ? cGreen.$1 : muted,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    ),
  );
}
