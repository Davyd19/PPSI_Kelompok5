import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import '../../widgets/dashboard_widgets.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final Map<String, String> _attendance = {};
  Future<void> _scan() async {
    String selected = 'Pagi';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Simulasi Scan QR'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kamera dan validasi QR belum terhubung. Presensi contoh hanya berlaku selama sesi ini.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: ['Pagi', 'Zuhur']
                      .map(
                        (s) => ChoiceChip(
                          label: Text(s),
                          selected: selected == s,
                          onSelected: (_) => update(() => selected = s),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  _attendance.containsKey(selected)
                      ? 'Presensi $selected sudah tercatat. Tidak dapat diisi dua kali.'
                      : 'Konfirmasi untuk mencatat presensi contoh.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: _attendance.containsKey(selected)
                  ? null
                  : () => Navigator.pop(context, selected),
              child: const Text('Konfirmasi'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted || _attendance.containsKey(result)) return;
    final now = TimeOfDay.now();
    setState(
      () => _attendance[result] =
          '${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}',
    );
  }

  void _badge() => showDetails(
    context,
    title: 'Badge Rajin',
    child: Text(
      '${widget.data['badge']['description']}\n\n${widget.data['badge']['detail']}',
    ),
  );
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final badge = data['badge'];
    final summary = data['attendanceSummary'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 23,
              backgroundColor: Color(0xFFE0EAF8),
              child: Icon(Icons.person_outline, color: navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selamat Pagi,', style: TextStyle(fontSize: 11)),
                  Text(
                    data['student']['name'],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${data['student']['classroom']} • NISN: ${data['student']['nisn']}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppPanel(
          color: navy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Text(
                    '24 Sesi Tepat Waktu',
                    style: TextStyle(
                      color: Color(0xFF7EE8C6),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  Pill(
                    _attendance['Pagi'] != null
                        ? '${_attendance['Pagi']} • Hadir'
                        : 'Presensi Sekolah',
                    color: const Color(0xFF0B584D),
                    foreground: const Color(0xFF7EE8C6),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum']
                    .map(
                      (day) => Column(
                        children: [
                          Text(
                            day,
                            style: const TextStyle(
                              color: Color(0xFFB8CCE3),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: day == 'Jum'
                                ? const Color(0xFF7B93AD)
                                : const Color(0xFF82EAC8),
                            child: Icon(
                              day == 'Jum' ? Icons.more_horiz : Icons.check,
                              size: 15,
                              color: navy,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              ...['Pagi', 'Zuhur'].map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    children: [
                      Icon(
                        _attendance.containsKey(s)
                            ? Icons.check_circle_outline
                            : Icons.circle_outlined,
                        size: 17,
                        color: const Color(0xFFB9D8E9),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Presensi $s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _attendance.containsKey(s)
                              ? 'Hadir • ${_attendance[s]}'
                              : 'Belum presensi',
                          style: const TextStyle(
                            color: Color(0xFFB9D8E9),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FilledButton.icon(
                onPressed: _scan,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: navy,
                ),
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Scan QR'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Metric(
                'Kehadiran',
                summary['percentage'],
                icon: Icons.calendar_today_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _badge,
                child: const Metric(
                  'Progres Badge',
                  '24 / 30',
                  icon: Icons.workspace_premium_outlined,
                ),
              ),
            ),
          ],
        ),
        const SectionTitle('Aktivitas Terbaru', caption: 'Informasi siswa'),
        ActivityTile(
          title: 'Badge Aktif Berkegiatan',
          subtitle: 'Level 1 • Diperoleh otomatis kemarin',
          icon: Icons.workspace_premium_outlined,
          onTap: () => showDetails(
            context,
            title: 'Aktif Berkegiatan',
            child: Text(badge['earnedDetail']),
          ),
        ),
        ActivityTile(
          title: 'Riwayat Kehadiran',
          subtitle: '${summary['description']} • ${data['period']}',
          icon: Icons.calendar_month_outlined,
          onTap: () => showDetails(
            context,
            title: 'Ringkasan kehadiran',
            child: Text('${summary['breakdown']}\n${summary['note']}'),
          ),
        ),
        const SectionTitle('Agenda Terdekat', caption: 'Ekstrakurikuler'),
        ...(data['agendas'] as List).map(
          (a) => ActivityTile(
            title: a['title'],
            subtitle: '${a['time']} • ${a['place']}',
            icon: Icons.sports_basketball_outlined,
            onTap: () => showDetails(
              context,
              title: a['title'],
              child: Text('${a['description']}\n\n${a['time']}\n${a['place']}'),
            ),
          ),
        ),
      ],
    );
  }
}
