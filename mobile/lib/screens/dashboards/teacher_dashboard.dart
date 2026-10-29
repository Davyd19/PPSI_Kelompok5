import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import '../../widgets/dashboard_widgets.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({
    super.key,
    required this.data,
    this.isGuardian = false,
  });
  final Map<String, dynamic> data;
  final bool isGuardian;
  @override
  Widget build(BuildContext context) {
    final t = data['teacher'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 10,
                runSpacing: 8,
                children: [
                  Text(
                    data['dateLabel'],
                    style: const TextStyle(
                      color: Color(0xFF236A7C),
                      fontSize: 10,
                    ),
                  ),
                  const Pill(
                    'Semester Ganjil',
                    color: Color(0xFFBCEFF8),
                    foreground: Color(0xFF236A7C),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Selamat Pagi, ${data['profile']['name']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school_outlined, color: Color(0xFF236A7C)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGuardian ? 'Kelas Binaan' : 'Kelas Rekap',
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            t['classroom'],
                            style: const TextStyle(
                              fontSize: 16,
                              color: navy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${t['students']} siswa • Tahun ajaran 2026/2027',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SectionTitle(isGuardian ? 'Aksi Cepat Wali Kelas' : 'Aksi Cepat Guru'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ActionTile(
                isGuardian ? 'Kasus Binaan' : 'Buka Sesi Presensi',
                icon: isGuardian ? Icons.folder_open : Icons.qr_code,
                onTap: () => unavailable(
                  context,
                  isGuardian
                      ? 'Kasus binaan kelas'
                      : 'Buka sesi presensi sekolah',
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: ActionTile(
                isGuardian ? 'Tindak Lanjut' : 'Lapor Pelanggaran',
                icon: Icons.edit_note,
                onTap: () => unavailable(
                  context,
                  isGuardian
                      ? 'Tindak lanjut pembinaan'
                      : 'Laporan pelanggaran',
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: ActionTile(
                'Rekap Kehadiran',
                icon: Icons.description_outlined,
                onTap: () => unavailable(context, 'Rekap kehadiran'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    isGuardian
                        ? 'Kehadiran Kelas Binaan'
                        : 'Monitoring Presensi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    '90,0%',
                    style: TextStyle(
                      color: Color(0xFF236A7C),
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              Text(
                '${t['classroom']} • Hari ini',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 14),
              SummaryCounts(
                items: {
                  'Hadir': '${t['present']}',
                  'Izin': '${t['permit']}',
                  'Sakit': '${t['sick']}',
                  'Belum Diisi': '${t['pending']}',
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Belum Diisi tidak otomatis menjadi Alfa.',
                style: TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        SectionTitle(
          isGuardian ? 'Pendampingan Kelas' : 'Sesi Presensi Sekolah',
          caption: isGuardian ? '2 kasus binaan' : 'Seluruh sekolah',
        ),
        if (isGuardian) ...[
          ActivityTile(
            title: 'Kasus binaan kelas',
            subtitle: '2 kasus • Ringkasan sesuai kewenangan',
            icon: Icons.folder_open_outlined,
            onTap: () => unavailable(context, 'Kasus binaan kelas'),
          ),
          ActivityTile(
            title: 'Pelibatan Orang Tua',
            subtitle: 'Catat tindak lanjut dan keterlibatan orang tua',
            icon: Icons.people_outline,
            onTap: () => unavailable(context, 'Pelibatan orang tua'),
          ),
        ] else
          AppPanel(
            child: Column(
              children: (t['sessions'] as List)
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(
                              s['time'],
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['title'],
                                  style: const TextStyle(
                                    color: navy,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  s['location'],
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Pill(
                              s['status'],
                              color: const Color(0xFFEAF0FA),
                              foreground: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
