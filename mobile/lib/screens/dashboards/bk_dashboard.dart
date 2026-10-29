import 'package:flutter/material.dart';
import '../../widgets/shared.dart';
import '../../widgets/dashboard_widgets.dart';

class BkDashboard extends StatelessWidget {
  const BkDashboard({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final b = data['counseling'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Pill(
                'PENDAMPINGAN SISWA',
                color: Color(0xFFBCF1F8),
                foreground: Color(0xFF236A7C),
              ),
              const SizedBox(height: 14),
              Text(
                'Selamat Pagi, ${data['profile']['name']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(data['dateLabel'], style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 14),
              const Text(
                'Rencana dan tindak lanjut penanganan siswa sesuai kewenangan.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Metric(
                'Kasus Ditangani',
                '${b['cases']}',
                icon: Icons.folder_open_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Metric(
                'Rencana Konseling',
                '${b['plans']}',
                icon: Icons.calendar_month_outlined,
              ),
            ),
          ],
        ),
        const SectionTitle('Aksi Cepat Guru BK'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ActionTile(
                'Verifikasi Laporan',
                icon: Icons.fact_check_outlined,
                onTap: () => unavailable(context, 'Verifikasi laporan'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: ActionTile(
                'Rencana Konseling',
                icon: Icons.event_note,
                onTap: () => unavailable(context, 'Rencana konseling'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: ActionTile(
                'Catat Konseling',
                icon: Icons.edit_note,
                onTap: () => unavailable(context, 'Asesmen dan konseling'),
              ),
            ),
          ],
        ),
        const SectionTitle('Agenda Penanganan', caption: 'Hari ini'),
        ...(b['items'] as List).map(
          (a) => ActivityTile(
            title: a['title'],
            subtitle: '${a['time']} • ${a['subtitle']}',
            icon: Icons.schedule,
            onTap: () => unavailable(context, a['title']),
          ),
        ),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tindak Lanjut',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text('${b['followUps']} tindak lanjut dalam agenda penanganan.'),
              const SizedBox(height: 8),
              const Text(
                'Informasi internal hanya untuk Guru BK sesuai kewenangan.',
                style: TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
