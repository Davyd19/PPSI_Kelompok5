import 'package:flutter/material.dart';
import '../../network/auth_api.dart';
import '../../theme.dart';
import '../../widgets/shared.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.api, this.onBack});
  final AuthApi? api;
  final VoidCallback? onBack;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  String _activeFilter = 'all';
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
        final res = await widget.api!.studentNotifications();
        if (mounted) {
          final tabs = (res['filter_tabs'] as List?) ?? [];
          final keys = tabs.map((t) => t['key']?.toString()).toSet();
          setState(() {
            _data = res;
            if (!keys.contains(_activeFilter)) {
              _activeFilter = 'all';
            }
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
        await widget.api!.studentMarkNotificationsRead();
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

  IconData? _iconForTab(String key) {
    final k = key.toUpperCase();
    if (k == 'ALL') return null;
    if (k.contains('PRESENSI') || k.contains('ATTENDANCE')) {
      return Icons.fact_check_outlined;
    }
    if (k.contains('PELANGGARAN') || k.contains('VIOLATION')) {
      return Icons.error_outline;
    }
    if (k.contains('PRESTASI')) return Icons.emoji_events_outlined;
    if (k.contains('BADGE')) return Icons.workspace_premium_outlined;
    return Icons.notifications_none;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _data?['unread_count'] as int? ?? 0;
    final groups =
        (_data?['groups'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final rawTabs =
        (_data?['filter_tabs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final filterTabs = rawTabs.isNotEmpty
        ? rawTabs
        : [
            {'key': 'all', 'label': 'Semua', 'count': 0},
          ];

    final hasVisibleItems = groups.any((group) {
      final items =
          (group['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      return items.any((it) {
        if (_activeFilter == 'all') return true;
        return (it['type'] as String? ?? '') == _activeFilter;
      });
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: widget.onBack != null
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: navy,
              elevation: 0,
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: const Text(
                'Notifikasi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: navy,
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null && _data == null)
          ? LoadErrorView(message: _error!, onRetry: _loadNotifications)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      // Header Bar: Unread Count + Button Tandai semua dibaca
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
                                  color: Color(0xFF0F2942),
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
                      const SizedBox(height: 14),

                      // Dynamic Filter Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (int i = 0; i < filterTabs.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              _buildFilterPill(
                                filterTabs[i]['key']?.toString() ?? 'all',
                                filterTabs[i]['label']?.toString() ?? 'Semua',
                                (filterTabs[i]['count'] as num?)?.toInt() ?? 0,
                                icon: _iconForTab(
                                  filterTabs[i]['key']?.toString() ?? 'all',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (!hasVisibleItems) ...[
                        const SizedBox(height: 40),
                        const Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 48,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Tidak Ada Notifikasi',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F2942),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Belum ada notifikasi untuk Anda.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ] else ...[
                        // Grouped Notifications
                        ...groups.map((group) {
                          final items =
                              (group['items'] as List?)
                                  ?.cast<Map<String, dynamic>>() ??
                              [];

                          final filtered = items.where((it) {
                            if (_activeFilter == 'all') return true;
                            final type = it['type'] as String? ?? '';
                            return type == _activeFilter;
                          }).toList();

                          if (filtered.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Group Header
                              Row(
                                children: [
                                  Text(
                                    group['group_name'] as String? ?? '',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F2942),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF94A3B8),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    group['date_label'] as String? ?? '',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (group['badge_label'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        group['badge_label'] as String,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Items
                              ...filtered.map(
                                (item) => _buildNotificationCard(item),
                              ),
                              const SizedBox(height: 10),
                            ],
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFilterPill(
    String key,
    String label,
    int count, {
    IconData? icon,
  }) {
    final isSelected = _activeFilter == key;
    return InkWell(
      onTap: () => setState(() => _activeFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F2942) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0F2942)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final unread = item['unread'] as bool? ?? false;
    final color = item['color'] as Color? ?? const Color(0xFF0D9488);
    final isViolation = item['is_violation'] as bool? ?? false;
    final tags = (item['tags'] as List?)?.cast<String>() ?? [];
    final badgeInfo = item['badge_info'] as Map<String, dynamic>?;

    return InkWell(
      onTap: () {
        final notifId = item['id'] as int?;
        if (notifId == null) return;
        setState(() => item['unread'] = false);
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => NotificationDetailScreen(
                  api: widget.api,
                  notificationId: notifId,
                ),
              ),
            )
            .then((_) => _loadNotifications());
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isViolation
                ? const Color(0xFFFECACA)
                : const Color(0xFFF1F5F9),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06082B50),
              blurRadius: 8,
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
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item['icon'] as IconData? ?? Icons.notifications,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['category'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        item['title'] as String? ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F2942),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item['time_ago'] as String? ?? '',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isViolation
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF0D9488),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              item['description'] as String? ?? '',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),

            if (badgeInfo != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFBAE6FD),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.star,
                          size: 16,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            badgeInfo['title'] as String? ?? '',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                          Text(
                            badgeInfo['subtitle'] as String? ?? '',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF0284C7),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: const Text(
                        'Lihat Profil',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.map((t) {
                  final isDemerit = t.contains('Demerit');
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDemerit
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDemerit
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF475569),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
