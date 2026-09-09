import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String _filter = 'ALL';
  String _error = '';
  List<dynamic> _tickets = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final tickets = await _api.getSupportTickets(user.id);
      if (!mounted) return;
      setState(() => _tickets = tickets);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleTickets = _filter == 'ALL'
        ? _tickets
        : _tickets.where((ticket) => ticket['status'] == _filter).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Support Tickets')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _heroCard(context),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['ALL', 'OPEN', 'IN_PROGRESS', 'RESOLVED']
                  .map((status) => ChoiceChip(
                        label: Text(status.replaceAll('_', ' ')),
                        selected: _filter == status,
                        onSelected: (_) => setState(() => _filter = status),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            if (_error.isNotEmpty)
              _infoCard(
                context,
                title: 'Could not load tickets',
                subtitle: _error,
                color: AppTheme.danger,
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visibleTickets.isEmpty)
              _emptyState(context)
            else
              ...visibleTickets.map((ticket) => _ticketCard(context, ticket)),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B2440), Color(0xFF0F1320)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF2A3558)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Track every support conversation',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Feedback, problem reports, and contact requests yahin ticket form me dikhte hain, along with their current status.',
            style: TextStyle(color: Color(0xFFB6BFD8), height: 1.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metric('Open', _countStatus('OPEN')),
              _metric('In Progress', _countStatus('IN_PROGRESS')),
              _metric('Resolved', _countStatus('RESOLVED')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFFB6BFD8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _ticketCard(BuildContext context, dynamic ticket) {
    final statusColor = _statusColor(ticket['status'] as String?);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'TICKET #${ticket['id']}',
                style: const TextStyle(
                  color: AppTheme.textSec,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _pill(
                  ticket['type']?.toString().replaceAll('_', ' ') ?? 'Support',
                  AppTheme.textSec),
              _pill(ticket['status']?.toString().replaceAll('_', ' ') ?? 'Open',
                  statusColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ticket['subject']?.toString() ?? 'Support Request',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${ticket['category'] ?? 'General'} · ${ticket['appPlatform'] ?? 'flutter'} · ${_formatDate(ticket['createdAt']?.toString())}',
            style: const TextStyle(color: AppTheme.textSec, fontSize: 13),
          ),
          if ((ticket['pagePath'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Source: ${ticket['pagePath']}',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            ticket['message']?.toString() ?? '',
            style: const TextStyle(color: AppTheme.textSec, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const Text('🎫', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 12),
          Text(
            'No tickets yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Jab aap feedback, problem report, ya contact request bhejte ho, uski status history yahin dikhegi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSec, height: 1.6),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/support'),
            child: const Text('Open Support Hub'),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _infoCard(BuildContext context,
      {required String title, required String subtitle, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(color: AppTheme.textSec, height: 1.5)),
        ],
      ),
    );
  }

  int _countStatus(String status) =>
      _tickets.where((ticket) => ticket['status'] == status).length;

  Color _statusColor(String? status) {
    switch (status) {
      case 'RESOLVED':
        return AppTheme.accent2;
      case 'IN_PROGRESS':
        return AppTheme.accent;
      default:
        return AppTheme.warning;
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Recently';
    final date = DateTime.tryParse(raw);
    if (date == null) return 'Recently';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
