import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import 'extracurricular_detail_screen.dart';

class ExtracurricularListScreen extends StatefulWidget {
  const ExtracurricularListScreen({super.key, this.api});
  final AuthApi? api;

  @override
  State<ExtracurricularListScreen> createState() =>
      _ExtracurricularListScreenState();
}

class _ExtracurricularListScreenState extends State<ExtracurricularListScreen> {
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'Semua';
  String _searchQuery = '';
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadEkskul();
  }

  Future<void> _loadEkskul() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.api != null) {
        final res = await widget.api!.studentExtracurriculars();
        if (mounted) setState(() => _data = res);
      } else {
        if (mounted) {
          setState(() {
            _data = {
              'summary': {'enrolled_count': 0, 'academic_year': '-'},
              'categories': ['Semua', 'Diikuti'],
              'items': <Map<String, dynamic>>[],
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

  @override
  Widget build(BuildContext context) {
    final summary = _data?['summary'] as Map<String, dynamic>?;
    final allItems =
        (_data?['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final filtered = allItems.where((item) {
      final name = (item['name'] as String? ?? '').toLowerCase();
      final cat = (item['category'] as String? ?? '');
      final isEnrolled = item['is_enrolled'] as bool? ?? false;

      if (_searchQuery.isNotEmpty &&
          !name.contains(_searchQuery.toLowerCase())) {
        return false;
      }

      if (_selectedCategory == 'Diikuti' ||
          _selectedCategory == 'Diikuti (2)') {
        return isEnrolled;
      }
      if (_selectedCategory.startsWith('Semua')) return true;
      return cat.toLowerCase().contains(_selectedCategory.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Ekstrakurikuler',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: navy,
              ),
            ),
            Text(
              'SMAN 12 Padang',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0284C7),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: navy, size: 20),
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
          ? LoadErrorView(message: _error!, onRetry: _loadEkskul)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: RefreshIndicator(
                  onRefresh: _loadEkskul,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      // Keanggotaan banner card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF132B45),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified,
                              color: Color(0xFF38BDF8),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'KEANGGOTAAN',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF94A3B8),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${summary?['enrolled_count'] ?? 0} Ekskul Diikuti',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                summary?['academic_year'] as String? ?? '-',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF93C5FD),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Search Bar
                      TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Cari ekstrakurikuler...',
                          hintStyle: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              ((_data?['categories'] as List?)
                                          ?.cast<String>() ??
                                      ['Semua', 'Diikuti'])
                                  .map((cat) {
                                    final isSelected = _selectedCategory == cat;
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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

                      // Extracurricular Cards
                      if (filtered.isEmpty)
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
                                Icons.sports_soccer_outlined,
                                size: 40,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Tidak Ada Data Ekstrakurikuler',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F2942),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tidak ada kegiatan ekstrakurikuler yang sesuai.',
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
                        ...filtered.map((item) {
                          final isEnrolled =
                              item['is_enrolled'] as bool? ?? false;
                          final tag = item['tag'] as String? ?? 'Terbuka';
                          final color =
                              item['color'] as Color? ??
                              const Color(0xFF0D9488);
                          final icon =
                              item['icon'] as IconData? ?? Icons.extension;

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
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(icon, color: color, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (item['category'] as String? ?? '')
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: color,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            item['name'] as String? ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F2942),
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
                                        color: isEnrolled
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isEnrolled) ...[
                                            const Icon(
                                              Icons.check_circle,
                                              color: Color(0xFF16A34A),
                                              size: 11,
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            tag,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: isEnrolled
                                                  ? const Color(0xFF16A34A)
                                                  : const Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item['description'] as String? ?? '',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Divider(
                                  height: 1,
                                  color: Color(0xFFF1F5F9),
                                ),
                                const SizedBox(height: 8),

                                // Schedule & Coach row
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.access_time,
                                                size: 13,
                                                color: Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  item['schedule'] as String? ??
                                                      '',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.person_outline,
                                                size: 13,
                                                color: Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  item['coach'] as String? ??
                                                      '',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isEnrolled)
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ExtracurricularDetailScreen(
                                                    api: widget.api,
                                                    ekskulId:
                                                        item['id'] as int? ?? 1,
                                                    name:
                                                        item['name']
                                                            as String? ??
                                                        '',
                                                  ),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          'Detail Kegiatan',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      )
                                    else
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF0F2942,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ExtracurricularDetailScreen(
                                                    api: widget.api,
                                                    ekskulId:
                                                        item['id'] as int? ?? 3,
                                                    name:
                                                        item['name']
                                                            as String? ??
                                                        '',
                                                  ),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          'Daftar >',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 10),
                      // Notice at bottom
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Wajib pilih min. 1 ekskul peminatan. Info hubungi Kesiswaan.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF475569),
                                ),
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
