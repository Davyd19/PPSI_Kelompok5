import 'auth_api.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

int _n(Object? v) => (v as num?)?.toInt() ?? 0;

/// Jumlah status kehadiran (per siswa atau total).
class AttendanceCounts {
  const AttendanceCounts({
    required this.present,
    required this.late,
    required this.permit,
    required this.sick,
    required this.absent,
    required this.excused,
    required this.pending,
    required this.sessions,
  });
  factory AttendanceCounts.fromJson(Map<String, dynamic> j) => AttendanceCounts(
    present: _n(j['hadir']),
    late: _n(j['terlambat']),
    permit: _n(j['izin']),
    sick: _n(j['sakit']),
    absent: _n(j['alfa']),
    excused: _n(j['pengecualian_sah']),
    pending: _n(j['belum_diisi']),
    sessions: _n(j['total_sesi']),
  );

  final int present, late, permit, sick, absent, excused, pending, sessions;

  /// Persentase kehadiran (Hadir + Terlambat) dari sesi yang sudah tercatat,
  /// tanpa menghitung Pengecualian Sah dan Belum Diisi (tidak otomatis Alfa).
  double? get rate {
    final base = sessions - excused - pending;
    return base <= 0 ? null : (present + late) / base;
  }
}

class RecapRow {
  const RecapRow({
    required this.studentId,
    required this.name,
    required this.nis,
    required this.nisn,
    required this.classroom,
    required this.counts,
  });
  factory RecapRow.fromJson(Map<String, dynamic> j) => RecapRow(
    studentId: j['id_siswa'] as int,
    name: j['nama'] as String,
    nis: j['nis'] as String?,
    nisn: j['nisn'] as String? ?? '-',
    classroom: j['kelas'] as String? ?? '-',
    counts: AttendanceCounts.fromJson(j),
  );
  final int studentId;
  final String name, nisn, classroom;
  final String? nis;
  final AttendanceCounts counts;
}

class RecapPage {
  const RecapPage({
    required this.rows,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.sessionCount,
    required this.summary,
  });
  final List<RecapRow> rows;
  final int total, page, pageSize, sessionCount;
  final AttendanceCounts summary;
  bool get hasMore => page * pageSize < total;
}

class RecapClass {
  const RecapClass(this.id, this.name);
  final int id;
  final String name;
}

class HistoryEntry {
  const HistoryEntry({
    required this.date,
    required this.type,
    required this.classroom,
    required this.status,
    required this.sessionStatus,
    this.method,
    this.time,
    this.note,
    this.recordedBy,
  });
  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
    date: j['tanggal'] as String,
    type: j['jenis_sesi'] as String,
    classroom: j['kelas'] as String? ?? '-',
    status: j['status_kehadiran'] as String,
    sessionStatus: j['status_sesi'] as String,
    method: j['metode'] as String?,
    time: j['waktu_presensi'] is String
        ? DateTime.parse(j['waktu_presensi'] as String).toLocal()
        : null,
    note: j['keterangan'] as String?,
    recordedBy: j['pencatat'] as String?,
  );
  final String date, type, classroom, status, sessionStatus;
  final String? method, note, recordedBy;
  final DateTime? time;
}

/// Filter rekap; `null` berarti semua.
class RecapFilter {
  const RecapFilter({
    required this.start,
    required this.end,
    this.classId,
    this.type,
    this.query = '',
  });
  final DateTime start, end;
  final int? classId;
  final String? type;
  final String query;

  Map<String, String> params([int? page]) => {
    'mulai': _ymd(start),
    'sampai': _ymd(end),
    if (classId != null) 'kelas': '$classId',
    'jenis': ?type,
    if (query.trim().isNotEmpty) 'q': query.trim(),
    if (page != null) 'page': '$page',
  };
}

/// Klien API modul "Melihat Rekap Kehadiran" untuk peran Guru.
class AttendanceRecapApi {
  const AttendanceRecapApi(this._api);
  final AuthApi _api;

  Future<List<RecapClass>> classes() async => [
    for (final r in await _api.send('/guru/presensi/kelas') as List)
      RecapClass((r as Map)['id'] as int, r['nama'] as String),
  ];

  Future<RecapPage> recap(RecapFilter filter, {int page = 1}) async {
    final json = await _api.sendWithMeta(
      '/guru/presensi/rekap?${Uri(queryParameters: filter.params(page)).query}',
    );
    final meta = json['meta'] as Map<String, dynamic>;
    return RecapPage(
      rows: [
        for (final r in json['data'] as List)
          RecapRow.fromJson(r as Map<String, dynamic>),
      ],
      total: _n(meta['total']),
      page: _n(meta['page']),
      pageSize: _n(meta['page_size']),
      sessionCount: _n(meta['jumlah_sesi']),
      summary: AttendanceCounts.fromJson(
        meta['ringkasan'] as Map<String, dynamic>,
      ),
    );
  }

  Future<List<HistoryEntry>> history(int studentId, RecapFilter filter) async {
    final params = filter.params()
      ..remove('kelas')
      ..remove('q');
    final data =
        await _api.send(
              '/guru/presensi/rekap/siswa/$studentId?'
              '${Uri(queryParameters: params).query}',
            )
            as Map<String, dynamic>;
    return [
      for (final r in data['riwayat'] as List)
        HistoryEntry.fromJson(r as Map<String, dynamic>),
    ];
  }
}
