import 'auth_api.dart';

class ViolationCategory {
  const ViolationCategory(this.id, this.name, this.description);
  final int id;
  final String name;
  final String? description;
}

class ViolationForm {
  const ViolationForm(this.categories, this.classes, this.maxAttachments);
  final List<ViolationCategory> categories;
  final List<({int id, String name})> classes;
  final int maxAttachments;
}

class ReportableStudent {
  const ReportableStudent({
    required this.id,
    required this.name,
    required this.classroom,
    this.nis,
    this.nisn,
  });
  final int id;
  final String name, classroom;
  final String? nis, nisn;
}

class MyReport {
  const MyReport({
    required this.id,
    required this.student,
    required this.category,
    required this.occurredAt,
    required this.status,
    required this.attachments,
    this.classroom,
    this.place,
    this.description,
    this.verificationNote,
  });
  final int id, attachments;
  final String student, category, status;
  final DateTime occurredAt;
  final String? classroom, place, description, verificationNote;
}

/// Klien API use case "Menginput Laporan Pelanggaran" (peran Guru).
class ViolationReportApi {
  const ViolationReportApi(this._api);
  final AuthApi _api;

  Future<ViolationForm> form() async {
    final d =
        await _api.send('/guru/pelanggaran/formulir') as Map<String, dynamic>;
    return ViolationForm(
      [
        for (final k in d['kategori'] as List)
          ViolationCategory(
            (k as Map)['id'] as int,
            k['nama'] as String,
            k['deskripsi'] as String?,
          ),
      ],
      [
        for (final c in d['kelas'] as List)
          (id: (c as Map)['id'] as int, name: c['nama'] as String),
      ],
      (d['maks_bukti'] as num?)?.toInt() ?? 3,
    );
  }

  Future<List<ReportableStudent>> students({
    String? query,
    int? classId,
  }) async {
    final params = {
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (classId != null) 'kelas': '$classId',
    };
    final rows =
        await _api.send(
              '/guru/pelanggaran/siswa'
              '${params.isEmpty ? '' : '?${Uri(queryParameters: params).query}'}',
            )
            as List;
    return [
      for (final r in rows)
        ReportableStudent(
          id: (r as Map)['id'] as int,
          name: r['nama'] as String,
          classroom: r['kelas'] as String? ?? '-',
          nis: r['nis'] as String?,
          nisn: r['nisn'] as String?,
        ),
    ];
  }

  /// Kirim laporan; melempar [AuthError] dengan `details` per kolom bila
  /// data belum lengkap (HTTP 422).
  Future<int> submit({
    required int studentId,
    required int categoryId,
    required DateTime occurredAt,
    required String place,
    required String description,
  }) async {
    final data =
        await _api.send(
              '/guru/pelanggaran',
              body: {
                'id_siswa': studentId,
                'id_kategori_pelanggaran': categoryId,
                'waktu_kejadian': _wib(occurredAt),
                'tempat_kejadian': place.trim(),
                'uraian': description.trim(),
              },
            )
            as Map<String, dynamic>;
    return data['id'] as int;
  }

  Future<void> uploadEvidence(
    int reportId, {
    required List<int> bytes,
    required String filename,
  }) {
    final lower = filename.toLowerCase();
    final type = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.pdf')
        ? 'application/pdf'
        : 'image/jpeg';
    return _api.upload(
      '/guru/pelanggaran/$reportId/bukti',
      bytes: bytes,
      contentType: type,
      filename: filename,
    );
  }

  /// Laporan milik guru ini. [query] mencari nama/NIS siswa, kategori,
  /// kelas, atau tempat kejadian di server.
  Future<({List<MyReport> rows, int total})> mine({
    int page = 1,
    String? query,
  }) async {
    final params = {
      'page': '$page',
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    };
    final json = await _api.sendWithMeta(
      '/guru/pelanggaran?${Uri(queryParameters: params).query}',
    );
    return (
      rows: [
        for (final r in json['data'] as List)
          MyReport(
            id: (r as Map)['id'] as int,
            student: r['siswa'] as String,
            classroom: r['kelas'] as String?,
            category: r['kategori'] as String,
            occurredAt: DateTime.parse(r['waktu_kejadian'] as String).toLocal(),
            place: r['tempat_kejadian'] as String?,
            description: r['uraian'] as String?,
            status: r['status_verifikasi'] as String,
            verificationNote: r['hasil_verifikasi'] as String?,
            attachments: (r['jumlah_bukti'] as num?)?.toInt() ?? 0,
          ),
      ],
      total: ((json['meta'] as Map)['total'] as num).toInt(),
    );
  }
}

/// Waktu perangkat -> string ISO WIB (+07:00) yang diminta server.
String _wib(DateTime local) {
  final w = local.toUtc().add(const Duration(hours: 7));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${w.year}-${two(w.month)}-${two(w.day)}T${two(w.hour)}:${two(w.minute)}:00+07:00';
}
