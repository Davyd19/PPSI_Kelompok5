import 'auth_api.dart';

/// Status kehadiran yang boleh dipilih guru saat input manual.
const manualAttendanceStatuses = {
  'HADIR': 'Hadir',
  'TERLAMBAT': 'Terlambat',
  'IZIN': 'Izin',
  'SAKIT': 'Sakit',
  'ALFA': 'Alfa',
  'PENGECUALIAN_SAH': 'Pengecualian Sah',
};

/// Pilihan dropdown pada tabel input manual per kelas.
const classAttendanceOptions = {
  'HADIR': 'Hadir',
  'IZIN': 'Izin',
  'ALFA': 'Alfa',
  'TERLAMBAT': 'Terlambat',
};

const attendanceStatusLabels = {
  ...manualAttendanceStatuses,
  'BELUM_DIISI': 'Belum Diisi',
};

class AttendanceSummary {
  const AttendanceSummary(this.counts);
  factory AttendanceSummary.fromJson(Map<String, dynamic>? json) =>
      AttendanceSummary({
        for (final entry in (json ?? const {}).entries)
          entry.key: (entry.value as num).toInt(),
      });
  final Map<String, int> counts;
  int get total => counts['total'] ?? 0;
  int operator [](String status) => counts[status] ?? 0;
  int get recorded => total - this['BELUM_DIISI'];
}

class SchoolSession {
  const SchoolSession({
    required this.id,
    required this.type,
    required this.status,
    required this.openedAt,
    required this.closedAt,
    required this.onTimeLimit,
    required this.openedBy,
    required this.isMine,
    required this.summary,
    this.qrValidUntil,
  });

  factory SchoolSession.fromJson(Map<String, dynamic> json) => SchoolSession(
    id: json['id'] as int,
    type: json['jenis_sesi'] as String,
    status: json['status'] as String,
    openedAt: _date(json['waktu_buka']),
    closedAt: _date(json['waktu_tutup']),
    onTimeLimit: _date(json['batas_tepat_waktu']),
    openedBy: json['guru_pembuka'] as String?,
    isMine: json['milik_saya'] == true,
    summary: AttendanceSummary.fromJson(
      json['ringkasan'] as Map<String, dynamic>?,
    ),
    qrValidUntil: _date(json['token_kedaluwarsa']),
  );

  final int id;
  final String type, status;
  final DateTime? openedAt, closedAt, onTimeLimit;
  final String? openedBy;
  final bool isMine;
  final AttendanceSummary summary;

  /// Batas berlaku QR; null bila sesi sudah ditutup.
  final DateTime? qrValidUntil;

  bool get isActive => status == 'AKTIF';
  bool get isQrActive =>
      isActive &&
      qrValidUntil != null &&
      qrValidUntil!.isAfter(DateTime.now());
  String get label => type == 'PAGI' ? 'Presensi Pagi' : 'Salat Zuhur';
}

class SchoolDay {
  const SchoolDay({
    required this.date,
    required this.hasSemester,
    required this.defaultLimits,
    required this.sessions,
  });
  factory SchoolDay.fromJson(Map<String, dynamic> json) => SchoolDay(
    date: json['tanggal'] as String,
    hasSemester: json['semester'] != null,
    defaultLimits: Map<String, String>.from(
      json['batas_bawaan'] as Map? ?? const {},
    ),
    sessions: [
      for (final s in json['sesi'] as List)
        SchoolSession.fromJson(s as Map<String, dynamic>),
    ],
  );
  final String date;
  final bool hasSemester;
  final Map<String, String> defaultLimits;
  final List<SchoolSession> sessions;

  SchoolSession? session(String type) {
    for (final s in sessions) {
      if (s.type == type) return s;
    }
    return null;
  }
}

/// Pilihan waktu berlaku QR (menit) beserta labelnya.
const qrDurationOptions = {
  5: '5 menit',
  10: '10 menit',
  15: '15 menit',
  30: '30 menit',
  60: '1 jam',
};
const defaultQrMinutes = 15;

/// QR statis satu sesi: dibuat sekali saat sesi dibuka dan sama untuk seluruh
/// siswa. Berlaku selama durasi pilihan guru, dapat ditutup lebih awal atau
/// diaktifkan lagi (paling lambat akhir hari).
class QrToken {
  const QrToken(this.code, this.validUntil);
  factory QrToken.fromJson(Map<String, dynamic> json) => QrToken(
    json['kode'] as String,
    DateTime.parse(json['berlaku_sampai'] as String).toLocal(),
  );
  final String code;
  final DateTime validUntil;

  Duration get remaining {
    final left = validUntil.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get isActive => remaining > Duration.zero;
}

class RosterStudent {
  const RosterStudent({
    required this.id,
    required this.name,
    required this.nisn,
    required this.classroom,
    required this.status,
    this.nis,
    this.method,
    this.note,
    this.recordedBy,
    this.recordedAt,
  });
  factory RosterStudent.fromJson(Map<String, dynamic> json) => RosterStudent(
    id: json['id_siswa'] as int,
    name: json['nama'] as String,
    nisn: json['nisn'] as String? ?? '-',
    classroom: json['kelas'] as String? ?? '-',
    status: json['status_kehadiran'] as String,
    nis: json['nis'] as String?,
    method: json['metode'] as String?,
    note: json['keterangan'] as String?,
    recordedBy: json['pencatat'] as String?,
    recordedAt: _date(json['waktu_presensi']),
  );
  final int id;
  final String name, nisn, classroom, status;
  final String? nis, method, note, recordedBy;
  final DateTime? recordedAt;
  bool get isPending => status == 'BELUM_DIISI';
}

class ClassroomOption {
  const ClassroomOption(this.id, this.name, this.total, this.pending);
  factory ClassroomOption.fromJson(Map<String, dynamic> json) =>
      ClassroomOption(
        json['id_kelas'] as int,
        json['kelas'] as String,
        (json['total'] as num).toInt(),
        (json['belum_diisi'] as num).toInt(),
      );
  final int id;
  final String name;
  final int total, pending;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.parse(value).toLocal() : null;

/// Klien API modul "Membuka Sesi Presensi Sekolah" untuk peran Guru.
class SchoolAttendanceApi {
  const SchoolAttendanceApi(this._api);
  final AuthApi _api;

  Future<SchoolDay> today() async => SchoolDay.fromJson(
    await _api.send('/guru/presensi/sesi') as Map<String, dynamic>,
  );

  Future<(SchoolSession, QrToken)> open(
    String type,
    String onTimeLimit, {
    int minutes = defaultQrMinutes,
  }) async {
    final data =
        await _api.send(
              '/guru/presensi/sesi',
              body: {
                'jenis_sesi': type,
                'batas_tepat_waktu': onTimeLimit,
                'berlaku_menit': minutes,
              },
            )
            as Map<String, dynamic>;
    return (
      SchoolSession.fromJson(data['sesi'] as Map<String, dynamic>),
      QrToken.fromJson(data['qr'] as Map<String, dynamic>),
    );
  }

  /// Menampilkan ulang QR sesi yang sudah dibuat (tidak membuat QR baru).
  Future<QrToken> qr(int sessionId) async => QrToken.fromJson(
    await _api.send('/guru/presensi/sesi/$sessionId/qr')
        as Map<String, dynamic>,
  );

  /// Menutup masa berlaku QR lebih awal; sesi tetap aktif untuk input manual.
  Future<QrToken> closeQr(int sessionId) async => QrToken.fromJson(
    await _api.send('/guru/presensi/sesi/$sessionId/qr/tutup', body: const {})
        as Map<String, dynamic>,
  );

  /// Mengatur ulang waktu berlaku QR yang sama (perpanjang / aktifkan lagi).
  Future<QrToken> extendQr(int sessionId, int minutes) async =>
      QrToken.fromJson(
        await _api.send(
              '/guru/presensi/sesi/$sessionId/qr/berlaku',
              body: {'berlaku_menit': minutes},
            )
            as Map<String, dynamic>,
      );

  Future<SchoolSession> close(int sessionId) async => SchoolSession.fromJson(
    await _api.send('/guru/presensi/sesi/$sessionId/tutup', body: const {})
        as Map<String, dynamic>,
  );

  Future<List<ClassroomOption>> classes(int sessionId) async => [
    for (final r
        in await _api.send('/guru/presensi/sesi/$sessionId/kelas') as List)
      ClassroomOption.fromJson(r as Map<String, dynamic>),
  ];

  Future<List<RosterStudent>> students(
    int sessionId, {
    int? classId,
    String? query,
    String? status,
  }) async {
    final params = {
      if (classId != null) 'kelas': '$classId',
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      'status': ?status,
    };
    final suffix = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final rows =
        await _api.send('/guru/presensi/sesi/$sessionId/siswa$suffix') as List;
    return [
      for (final r in rows) RosterStudent.fromJson(r as Map<String, dynamic>),
    ];
  }

  /// Simpan presensi manual satu kelas sekaligus (atomik di server).
  /// [entries]: id siswa -> (status, alasan per siswa). Alasan kosong memakai
  /// [commonReason].
  Future<void> manualBatch(
    int sessionId, {
    required int classId,
    required Map<int, ({String status, String reason})> entries,
    String? commonReason,
  }) => _api.send(
    '/guru/presensi/sesi/$sessionId/manual-kelas',
    body: {
      'id_kelas': classId,
      if (commonReason != null && commonReason.trim().isNotEmpty)
        'alasan': commonReason.trim(),
      'entri': [
        for (final e in entries.entries)
          {
            'id_siswa': e.key,
            'status_kehadiran': e.value.status,
            if (e.value.reason.trim().isNotEmpty)
              'alasan': e.value.reason.trim(),
          },
      ],
    },
  );

  Future<void> manual(
    int sessionId, {
    required int studentId,
    required String status,
    required String reason,
  }) => _api.send(
    '/guru/presensi/sesi/$sessionId/manual',
    body: {'id_siswa': studentId, 'status_kehadiran': status, 'alasan': reason},
  );
}
