import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final _api = ApiService();
  bool _loading = true;
  String _error = '';
  List<dynamic> _activities = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      final data = await _api.getActivityHistory(user.id);
      if (!mounted) return;
      setState(() {
        _activities = data;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'LISTING':
        return const Color(0xFF00D4AA);
      case 'BUYER_ORDER':
      case 'SELLER_ORDER':
        return const Color(0xFFF59E0B);
      case 'SUPPORT':
        return const Color(0xFF06B6D4);
      default:
        return const Color(0xFF5B4BFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      appBar: AppBar(title: const Text('Activity History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Text(_error,
                      style: const TextStyle(color: Color(0xFFEF4444))))
              : _activities.isEmpty
                  ? const Center(
                      child: Text('No activity yet',
                          style: TextStyle(color: Color(0xFF94A3B8))))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final activity = Map<String, dynamic>.from(
                            _activities[index] as Map);
                        final color =
                            _typeColor(activity['type']?.toString() ?? '');
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1320),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF1E2438)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        activity['title']?.toString() ??
                                            'Activity',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    Text(
                                        activity['description']?.toString() ??
                                            '',
                                        style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            height: 1.4)),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _chip(
                                            activity['type']?.toString() ??
                                                'EVENT',
                                            color),
                                        if (activity['status'] != null)
                                          _chip(activity['status'].toString(),
                                              const Color(0xFF475569)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: _activities.length,
                    ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
