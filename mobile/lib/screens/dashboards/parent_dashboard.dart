import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import '../../widgets/dashboard_widgets.dart';

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final p = data['parent'], s = data['attendanceSummary'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(p['child'], style: Theme.of(context).textTheme.titleLarge),
        Text(
          '${p['classroom']} • ${data['period']}',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Text(
                    'Kehadiran Anak',
                    style: TextStyle(color: navy, fontWeight: FontWeight.w600),
                  ),
                  Pill('${s['percentage']} Hadir'),
                ],
              ),
              const SizedBox(height: 16),
              const SummaryCounts(
                items: {'Hadir': '17', 'Sakit': '1', 'Izin': '0', 'Alfa': '0'},
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => unavailable(context, 'Riwayat kehadiran anak'),
                child: const Row(
                  children: [
                    Expanded(child: Text('Rekap Detail Presensi')),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionTitle('Ringkasan ${data['period']}', caption: 'Informasi anak'),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Kehadiran Siswa',
                style: TextStyle(
                  color: navy,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${s['percentage']} dari 18 sesi pagi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: 17 / 18,
                minHeight: 8,
                color: const Color(0xFF2F7183),
                backgroundColor: const Color(0xFFE3ECFA),
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 14),
              Text(s['note'], style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ActivityTile(
          title: 'Badge Rajin',
          subtitle: 'Progres 24 dari 30 sesi tepat waktu',
          icon: Icons.workspace_premium_outlined,
          onTap: () => showDetails(
            context,
            title: 'Badge anak',
            child: Text(data['badge']['detail']),
          ),
        ),
        ActivityTile(
          title: 'Ringkasan Penanganan Anak',
          subtitle: p['summary'],
          icon: Icons.shield_outlined,
          onTap: () => showDetails(
            context,
            title: 'Ringkasan penanganan',
            child: Text(p['summary']),
          ),
        ),
        const SectionTitle('Aktivitas Terkini', caption: 'Kehadiran sekolah'),
        ActivityTile(
          title: 'Presensi Sekolah',
          subtitle: '${p['activity']}\n${p['time']}',
          icon: Icons.check_circle_outline,
          onTap: () => showDetails(
            context,
            title: 'Presensi pagi',
            child: Text('${p['activity']}\n${p['time']}'),
          ),
        ),
        AppPanel(
          color: navy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'INFORMASI WALI KELAS',
                style: TextStyle(
                  color: Color(0xFF8DE8D4),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                p['guardian'],
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => unavailable(context, 'Hubungi wali kelas'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                child: const Text('Hubungi'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
