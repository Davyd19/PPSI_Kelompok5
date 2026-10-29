import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import '../../widgets/dashboard_widgets.dart';

class CoachDashboard extends StatelessWidget {
  const CoachDashboard({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final c = data['coach'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${data['academicPeriod']} • ${data['dateLabel']}',
          style: const TextStyle(fontSize: 10),
        ),
        const SizedBox(height: 8),
        Text(
          data['profile']['name'],
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Text(
          'Pembina Ekstrakurikuler',
          style: TextStyle(fontSize: 12, color: Color(0xFF236A7C)),
        ),
        const SizedBox(height: 24),
        AppPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFB6EDF9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sensors, color: Color(0xFF236A7C)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sesi Hari Ini • 15.30 WIB',
                      style: TextStyle(fontSize: 10, color: Color(0xFF236A7C)),
                    ),
                    const Text(
                      'Basket',
                      style: TextStyle(
                        color: navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const Text(
                      'Lapangan basket • Siap dibuka',
                      style: TextStyle(fontSize: 10),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          unavailable(context, 'Buka sesi presensi ekskul'),
                      child: const Text('Buka Sesi →'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Row(
            children: [
              Expanded(
                child: _Count('${c['totalActivities']}', 'Ekskul Dibina'),
              ),
              Expanded(child: _Count('${c['totalMembers']}', 'Total Anggota')),
              Expanded(child: _Count('${c['sessionsToday']}', 'Jadwal Sesi')),
            ],
          ),
        ),
        SectionTitle(
          'Kegiatan yang Dibina',
          caption: '${c['totalActivities']} Ekskul',
        ),
        ...(c['activities'] as List).indexed.map((entry) {
          final a = entry.$2;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AppPanel(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: entry.$1 == 0
                              ? const Color(0xFFE3F5ED)
                              : const Color(0xFFE7EEFC),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          entry.$1 == 0
                              ? Icons.sports_basketball_outlined
                              : Icons.forum_outlined,
                          color: const Color(0xFF236A7C),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a['name'],
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${a['members']} anggota • ${a['category']}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.circle,
                        color: Color(0xFF3FB48C),
                        size: 9,
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 16,
                        color: Color(0xFF236A7C),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${a['time']}\n${a['location']}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => unavailable(
                          context,
                          entry.$1 == 0
                              ? 'Presensi manual anggota'
                              : 'Detail kegiatan',
                        ),
                        child: Text(entry.$1 == 0 ? 'Presensi' : 'Detail'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const Text(
          'Presensi anggota dicatat manual oleh pembina.',
          style: TextStyle(fontSize: 10, color: muted),
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10),
      ),
    ],
  );
}
