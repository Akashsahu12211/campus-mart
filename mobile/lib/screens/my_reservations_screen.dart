import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../config/app_theme.dart';
import '../widgets/app_image.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({Key? key}) : super(key: key);

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _reservedItems = [];
  bool _loading = true;
  String? _message;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      
      if (user == null) {
        setState(() {
          _loading = false;
          _message = 'Please login first';
          _isSuccess = false;
        });
        return;
      }

      final items = await _apiService.getReservedItems(user.id);
      
      setState(() {
        _reservedItems = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _message = 'Failed to load reservations';
        _isSuccess = false;
      });
    }
  }

  Future<void> _unreserveItem(int itemId) async {
    try {
      await _apiService.unreserveItem(itemId);
      
      setState(() {
        _message = '✅ Reservation cancelled!';
        _isSuccess = true;
      });
      
      Future.delayed(const Duration(seconds: 2), () {
        _loadReservations();
      });
    } catch (e) {
      setState(() {
        _message = 'Failed to cancel reservation';
        _isSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔒 My Reservations'),
        backgroundColor: AppTheme.bg,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _reservedItems.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_message != null) ...[
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isSuccess
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              border: Border.all(
                                color: _isSuccess ? Colors.green : Colors.red,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _message!,
                              style: TextStyle(
                                color: _isSuccess ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Items you\'ve reserved - ${_reservedItems.length} total',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _reservedItems.length,
                        itemBuilder: (context, index) {
                          final item = _reservedItems[index];
                          return _buildReservationCard(item);
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No Reserved Items Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Start browsing and reserve items you\'re interested in!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Browse Items'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationCard(dynamic item) {
    final imageUrl = item['imageUrls'] != null && item['imageUrls'].isNotEmpty
        ? item['imageUrls'][0]
        : '';

    return Card(
      margin: const EdgeInsets.all(12),
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppImage(
                  source: imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    height: 150,
                    color: Colors.grey[800],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Title
            Text(
              item['title'] ?? 'Unknown Item',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Price
            Text(
              '₹${item['price']?.toString() ?? '0'}',
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Seller Info
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seller: ${item['seller']?['name'] ?? 'Unknown'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Phone: ${item['seller']?['phone'] ?? 'N/A'}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Condition
            Wrap(
              spacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item['condition'] ?? 'GOOD',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '🔒 RESERVED',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/item',
                        arguments: item['id'],
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                      side: const BorderSide(color: AppTheme.accent),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _unreserveItem(item['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
