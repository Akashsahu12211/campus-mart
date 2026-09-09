// lib/screens/offer_screen.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../models/item_model.dart';
import 'payment_screen.dart';

class OfferScreen extends StatefulWidget {
  final int itemId;
  final Map<String, dynamic>? item;

  const OfferScreen({
    Key? key,
    required this.itemId,
    this.item,
  }) : super(key: key);

  @override
  State<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends State<OfferScreen> {
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  final _apiService = ApiService();

  List<dynamic> offers = [];
  bool _loading = false;
  String _error = '';
  String _success = '';
  bool _showOfferForm = false;

  Future<void> _payAcceptedOffer(Map<String, dynamic> offer) async {
    final itemMap = widget.item;
    if (itemMap == null) return;

    final item = Item.fromJson(Map<String, dynamic>.from(itemMap));
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          item: item,
          amountOverride:
              (offer['offeredPrice'] as num?)?.toDouble() ?? item.price,
          descriptionOverride: '${item.title} (Accepted Offer)',
        ),
      ),
    );
    if (!mounted) return;
    _loadOffers();
  }

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() => _loading = true);
    try {
      final offersData = await _apiService.getOffersForItem(widget.itemId);
      setState(() {
        offers = offersData;
        _error = '';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitOffer() async {
    if (_priceController.text.isEmpty) {
      setState(() => _error = 'Please enter an offer price');
      return;
    }

    final price = double.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      setState(() => _error = 'Please enter a valid price');
      return;
    }

    setState(() => _loading = true);
    try {
      await _apiService.makeOffer({
        'itemId': widget.itemId,
        'offeredPrice': price,
        'note': _noteController.text,
      });

      setState(() {
        _success = 'Offer submitted successfully!';
        _error = '';
        _priceController.clear();
        _noteController.clear();
        _showOfferForm = false;
      });

      // Reload offers
      _loadOffers();

      // Clear message after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        setState(() => _success = '');
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _acceptOffer(int offerId) async {
    setState(() => _loading = true);
    try {
      await _apiService.acceptOffer(offerId);
      setState(() => _success = 'Offer accepted!');
      _loadOffers();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _rejectOffer(int offerId) async {
    setState(() => _loading = true);
    try {
      await _apiService.rejectOffer(offerId);
      setState(() => _success = 'Offer rejected');
      _loadOffers();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.user?.id;

    return Container(
      color: const Color(0xFF1A1F2E),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '💰 Offers',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (currentUserId != widget.item?['sellerId'])
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _showOfferForm = !_showOfferForm);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Make Offer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B4BFF),
                  ),
                )
            ],
          ),
          const SizedBox(height: 16),

          // Error/Success Messages
          if (_error.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '❌ $_error',
                style: const TextStyle(color: Color(0xFFFCA5A5)),
              ),
            ),
          if (_success.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '✅ $_success',
                style: const TextStyle(color: Color(0xFF86EFAC)),
              ),
            ),
          const SizedBox(height: 12),

          // Offer Form
          if (_showOfferForm && currentUserId != widget.item?['sellerId'])
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1419),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2D3748)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Make an Offer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Offer price (₹)',
                      hintStyle: const TextStyle(color: Color(0xFF718096)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2D3748)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A1F2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a note (optional)',
                      hintStyle: const TextStyle(color: Color(0xFF718096)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2D3748)),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1A1F2E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submitOffer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B4BFF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        _loading ? 'Submitting...' : 'Submit Offer',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Offers List
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B4BFF)),
              ),
            )
          else if (offers.isEmpty)
            Center(
              child: Text(
                currentUserId == widget.item?['sellerId']
                    ? 'No offers yet'
                    : 'No offers made',
                style: const TextStyle(color: Color(0xFFA0AEC0)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: offers.length,
              itemBuilder: (context, index) {
                final offer = offers[index];
                final status = offer['status'] ?? 'PENDING';
                final isPending = status == 'PENDING';
                final isAccepted = status == 'ACCEPTED';
                final isRejected = status == 'REJECTED';
                final isMyOffer = currentUserId == offer['buyer']?['id'];

                Color statusColor = Colors.grey;
                if (isPending) statusColor = const Color(0xFF5B4BFF);
                if (isAccepted) statusColor = const Color(0xFF00d4aa);
                if (isRejected) statusColor = const Color(0xFFef4444);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1419),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2D3748)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${offer['offeredPrice']}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF5B4BFF),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (offer['note'] != null &&
                          offer['note'].isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Note: ${offer['note']}',
                          style: const TextStyle(
                            color: Color(0xFFA0AEC0),
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'From: ${offer['buyer']?['name'] ?? 'Unknown'}',
                        style: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 12,
                        ),
                      ),
                      // Accept/Reject buttons for seller
                      if (currentUserId == widget.item?['sellerId'] &&
                          isPending) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () => _acceptOffer(offer['id']),
                              icon: const Icon(Icons.check),
                              label: const Text('Accept'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00d4aa),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _loading
                                  ? null
                                  : () => _rejectOffer(offer['id']),
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFef4444),
                                side: const BorderSide(
                                  color: Color(0xFFef4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (isAccepted && isMyOffer && widget.item != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _loading
                                ? null
                                : () => _payAcceptedOffer(
                                    Map<String, dynamic>.from(offer)),
                            icon: const Icon(Icons.payment_outlined),
                            label: const Text('Pay Accepted Offer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00d4aa),
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
