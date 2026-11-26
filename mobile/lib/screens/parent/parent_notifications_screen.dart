import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';

class ParentNotificationsScreen extends StatefulWidget {
  const ParentNotificationsScreen({
    super.key,
    this.api,
    this.childId,
    this.onBack,
  });

  final AuthApi? api;
  final int? childId;
  final VoidCallback? onBack;

  @override
  State<ParentNotificationsScreen> createState() =>
      _ParentNotificationsScreenState();
}

class _ParentNotificationsScreenState extends State<ParentNotificationsScreen> {
  bool _loading = true;
  String? _error;
  String _activeFilter = 'all';
  String _query = '';

  /// Notifikasi tampil bila cocok dengan tab aktif dan kata pencarian
  /// (judul, isi, kategori, atau nama anak).
  bool _visible(Map<String, dynamic> it) =>
      (_activeFilter == 'all' ||
          (it['type'] as String? ?? '') == _activeFilter) &&
      matchesSearch(_query, [
        it['title'] as String?,
        it['description'] as String?,
        it['category'] as String?,
        it['child_name']?.toString(),
      ]);
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.api != null) {
        final res = await widget.api!.parentNotifications(
          childId: widget.childId,
        );
        if (mounted) {
          final tabs = (res['filter_tabs'] as List?) ?? [];
          final keys = tabs.map((t) => t['key']?.toString()).toSet();
          setState(() {
            _data = res;
            if (!keys.contains(_activeFilter)) _activeFilter = 'all';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _data = {
              'unread_count': 0,
              'filter_tabs': [
                {'key': 'all', 'label': 'Semua', 'count': 0},
              ],
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

  Future<void> _markAllRead() async {
    try {
      if (widget.api != null) {
        await widget.api!.parentMarkNotificationsRead();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Semua notifikasi ditandai dibaca')),
        );
      }
      await _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menandai dibaca: $e')));
      }
    }
  }

  Future<void> _openDetail(Map<String, dynamic> item) async {
    final id = item['id'] as int?;
    if (id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ParentNotificationDetailScreen(
          api: widget.api,
          notificationId: id,
          childId: widget.childId,
        ),
      ),
    );
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = (_data?['unread_count'] as num?)?.toInt() ?? 0;
    final groups =
        (_data?['groups'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final rawTabs =
        (_data?['filter_tabs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final filterTabs = rawTabs.isNotEmpty
        ? rawTabs
        : [
            {'key': 'all', 'label': 'Semua', 'count': 0},
          ];

    final hasVisible = groups.any((g) {
      final items = (g['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      return items.any(_visible);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.onBack != null
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: navy,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: const Text(
                'Notifikasi',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null && _data == null)
          ? LoadErrorView(message: _error!, onRetry: _loadNotifications)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      // Pencarian selalu di paling atas halaman.
                      SchoolSearchField(
                        hint: 'Cari notifikasi atau nama anak',
                        initialValue: _query,
                        onChanged: (v) => setState(() => _query = v),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0D9488),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$unreadCount Notifikasi Baru',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: navy,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: _markAllRead,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.done_all,
                                    size: 14,
                                    color: Color(0xFF0284C7),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Tandai semua dibaca',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Dynamic filter tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (int i = 0; i < filterTabs.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              _filterPill(
                                filterTabs[i]['key']?.toString() ?? 'all',
                                filterTabs[i]['label']?.toString() ?? 'Semua',
                                (filterTabs[i]['count'] as num?)?.toInt() ?? 0,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (!hasVisible)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Column(
                            children: [
                              Icon(
                                _query.trim().isEmpty
                                    ? Icons.notifications_off_outlined
                                    : Icons.search_off,
                                size: 48,
                                color: const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _query.trim().isEmpty
                                    ? 'Belum ada notifikasi'
                                    : 'Tidak ditemukan',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: navy,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _query.trim().isEmpty
                                    ? 'Pemberitahuan terkait anak akan muncul di sini.'
                                    : 'Tidak ada notifikasi yang cocok dengan "${_query.trim()}".',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final g in groups) ..._buildGroup(g),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  List<Widget> _buildGroup(Map<String, dynamic> group) {
    final items = (group['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final filtered = items.where(_visible).toList();
    if (filtered.isEmpty) return const [];
    return [
      Row(
        children: [
          Text(
            group['group_name'] as String? ?? '',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '• ${group['date_label'] ?? ''}',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
        ],
      ),
      const SizedBox(height: 8),
      for (final item in filtered) _notifCard(item),
      const SizedBox(height: 10),
    ];
  }

  Widget _filterPill(String key, String label, int count) {
    final selected = _activeFilter == key;
    return InkWell(
      onTap: () => setState(() => _activeFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? navy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? navy : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : navy,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifCard(Map<String, dynamic> item) {
    final unread = item['unread'] == true;
    return InkWell(
      onTap: () => _openDetail(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7EDF5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item['category'] as String? ?? 'INFO',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ),
                Text(
                  item['time_ago'] as String? ?? '',
                  style: const TextStyle(fontSize: 10.5, color: muted),
                ),
                if (unread) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D9488),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item['title'] as String? ?? '-',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
            if (item['child_name'] != null) ...[
              const SizedBox(height: 2),
              Text(
                'Siswa: ${item['child_name']}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0369A1),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              item['description'] as String? ?? '',
              style: const TextStyle(fontSize: 12, color: muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class ParentNotificationDetailScreen extends StatefulWidget {
  const ParentNotificationDetailScreen({
    super.key,
    this.api,
    required this.notificationId,
    this.childId,
  });

  final AuthApi? api;
  final int notificationId;
  final int? childId;

  @override
  State<ParentNotificationDetailScreen> createState() =>
      _ParentNotificationDetailScreenState();
}

class _ParentNotificationDetailScreenState
    extends State<ParentNotificationDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.api != null) {
        final res = await widget.api!.parentNotificationDetail(
          widget.notificationId,
          childId: widget.childId,
        );
        if (mounted) setState(() => _data = res);
      } else {
        if (mounted) setState(() => _data = {});
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
    final jenis = _data?['jenis'] as String?;
    final dateTime = _data?['date_time'] as String?;
    final time = _data?['time'] as String?;
    final timestamp = [
      if (dateTime != null && dateTime.isNotEmpty) dateTime,
      if (time != null && time.isNotEmpty) time,
    ].join(' • ');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Notifikasi',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null && _data == null)
          ? LoadErrorView(message: _error!, onRetry: _loadDetail)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE7EDF5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (jenis != null && jenis.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                jenis.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Text(
                            _data?['title'] as String? ?? 'Notifikasi',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: navy,
                            ),
                          ),
                          if (timestamp.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              timestamp,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: muted,
                              ),
                            ),
                          ],
                          if (_data?['child_name'] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Siswa: ${_data!['child_name']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 14),
                          Text(
                            _data?['isi'] as String? ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
