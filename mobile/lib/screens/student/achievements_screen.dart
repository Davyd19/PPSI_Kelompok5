import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key, this.api});
  final AuthApi? api;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'Semua';
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.api != null) {
        final res = await widget.api!.studentAchievements();
        if (mounted) setState(() => _data = res);
      } else {
        if (mounted) {
          setState(() {
            _data = {
              'summary': {'total_achievements': 0, 'total_points': 0},
              'categories': ['Semua'],
              'groups': <Map<String, dynamic>>[],
            };
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _data = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSubmitDialog() {
    final titleController = TextEditingController();
    String category = 'Akademik';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Ajukan Prestasi Baru',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nama Kompetisi / Penghargaan:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: 'Misal: Juara 2 Lomba Puisi...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Kategori:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: category,
                items: ['Akademik', 'Seni & Budaya', 'Olahraga', 'Riset & STEM']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => category = val);
                },
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                try {
                  if (widget.api != null) {
                    await widget.api!.studentSubmitAchievement({
                      'judul': title,
                      'tingkat_prestasi': category,
                    });
                  }
                  await _loadAchievements();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Berkas prestasi berhasil diajukan!'),
                        backgroundColor: Color(0xFF0F2942),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gagal mengajukan prestasi: $e'),
                        backgroundColor: const Color(0xFFDC2626),
                      ),
                    );
                  }
                }
              },
              child: const Text('Kirim Pengajuan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _data?['summary'] as Map<String, dynamic>?;
    final groups =
        (_data?['groups'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, size: 14, color: navy),
          label: const Text(
            'Kembali',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: navy,
            ),
          ),
        ),
        leadingWidth: 90,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Prestasi Saya',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: navy,
              ),
            ),
            Text(
              'SIKAP SMAN 12 PADANG',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0284C7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined, color: navy, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: navy, size: 20),
            onPressed: () {},
          ),
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: const CircleAvatar(
              radius: 13,
              backgroundColor: Color(0xFFE0EAF8),
              child: Icon(Icons.person, size: 16, color: navy),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null && _data == null)
          ? LoadErrorView(message: _error!, onRetry: _loadAchievements)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: RefreshIndicator(
                  onRefresh: _loadAchievements,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // Summary Banner Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06082B50),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${summary?['total_achievements'] ?? 0} Prestasi',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F2942),
                                  ),
                                ),
                                const Text(
                                  'Tercatat Resmi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: const Color(0xFFE2E8F0),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.workspace_premium,
                                      size: 15,
                                      color: Color(0xFF0D9488),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+${summary?['total_points'] ?? 0} Poin',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0D9488),
                                      ),
                                    ),
                                  ],
                                ),
                                const Text(
                                  'Total Apresiasi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F2942),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _showSubmitDialog,
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text(
                              'Ajukan',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            ((_data?['categories'] as List?)?.cast<String>() ??
                                    ['Semua'])
                                .map((cat) {
                                  final isSelected =
                                      _selectedCategory == cat ||
                                      (_selectedCategory == 'Semua' &&
                                          cat.startsWith('Semua'));
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(
                                        cat,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                      selected: isSelected,
                                      selectedColor: const Color(0xFF0F2942),
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: BorderSide(
                                          color: isSelected
                                              ? const Color(0xFF0F2942)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      onSelected: (_) => setState(
                                        () => _selectedCategory = cat,
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Groups by Academic Year
                    if (groups.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 40,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: const [
                            Icon(
                              Icons.emoji_events_outlined,
                              size: 40,
                              color: Color(0xFF94A3B8),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Tidak Ada Data Prestasi',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F2942),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Belum ada prestasi yang tercatat untuk akun ini.\nKetuk "Ajukan" di atas untuk mendaftarkan prestasi.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...groups.map((group) {
                        final year = group['academic_year'] as String? ?? '';
                        final items =
                            (group['items'] as List?)
                                ?.cast<Map<String, dynamic>>() ??
                            [];

                        final filtered = items.where((it) {
                          if (_selectedCategory.startsWith('Semua')) {
                            return true;
                          }
                          final c = (it['category'] as String? ?? '')
                              .toLowerCase();
                          return c.contains(
                            _selectedCategory.split(' ').first.toLowerCase(),
                          );
                        }).toList();

                        if (filtered.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                year,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Timeline Items
                            ...filtered.map((item) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFF1F5F9),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x06082B50),
                                      blurRadius: 10,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.school_outlined,
                                                size: 12,
                                                color: Color(0xFF475569),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                item['category'] as String? ??
                                                    '',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            item['reward_points'] as String? ??
                                                '+30 Poin',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF16A34A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    Text(
                                      item['title'] as String? ?? '',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F2942),
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    Row(
                                      children: [
                                        Text(
                                          item['date'] as String? ?? '',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 3,
                                          height: 3,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF94A3B8),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.check_circle,
                                          size: 13,
                                          color: Color(0xFF10B981),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Terverifikasi',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.picture_as_pdf_outlined,
                                                size: 12,
                                                color: Color(0xFF1D4ED8),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                item['attachment_name']
                                                        as String? ??
                                                    'Sertifikat.pdf',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1D4ED8),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.visibility_outlined,
                                                size: 12,
                                                color: Color(0xFF1D4ED8),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        );
                      }),

                    const SizedBox(height: 10),
                    // Bottom Banner: Ada prestasi yang belum tercatat?
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDBEAFE),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.help_outline,
                                color: Color(0xFF1D4ED8),
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Ada prestasi yang belum tercatat?',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F2942),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _showSubmitDialog,
                            icon: const Icon(Icons.upload_file, size: 14),
                            label: const Text(
                              'Ajukan Berkas',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ),
            ),
    );
  }
}
