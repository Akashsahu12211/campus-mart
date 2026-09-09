import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/app_theme.dart';
import '../models/item_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class PaymentScreen extends StatefulWidget {
  final Item item;
  final double? amountOverride;
  final String? descriptionOverride;

  const PaymentScreen({
    super.key,
    required this.item,
    this.amountOverride,
    this.descriptionOverride,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _api = ApiService();
  Razorpay? _razorpay;
  bool _loading = false;
  String? _message;
  bool _success = false;
  Map<String, dynamic>? _paymentResult;

  double get _payableAmount => widget.amountOverride ?? widget.item.price;
  String get _description => widget.descriptionOverride ?? widget.item.title;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _startPayment() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final paymentConfig = await _api.getPaymentConfig();
      final keyId = (paymentConfig['keyId'] ?? '').toString();
      final configured = paymentConfig['configured'] == true;
      if (!configured || keyId.isEmpty) {
        throw Exception(
          (paymentConfig['message'] ?? 'Payments are not configured yet')
              .toString(),
        );
      }

      final orderData = await _api.createPaymentOrder(
        itemId: widget.item.id,
        amount: _payableAmount,
        notes: 'Buying: $_description',
      );

      final options = {
        'key': keyId,
        'amount': orderData['amount'],
        'currency': 'INR',
        'name': 'Campus Mart',
        'description': _description,
        'order_id': orderData['orderId'],
        'prefill': {
          'name': user.name,
          'email': user.email,
          'contact': user.phone ?? '',
        },
        'theme': {'color': '#5B4BFF'},
        'config': {
          'display': {
            'blocks': {
              'upi': {
                'name': 'Pay via UPI',
                'instruments': [
                  {'method': 'upi'}
                ]
              },
              'card': {
                'name': 'Cards',
                'instruments': [
                  {'method': 'card'}
                ]
              },
              'cod': {
                'name': 'Cash on Delivery',
                'instruments': [
                  {'method': 'cod'}
                ]
              }
            },
            'sequence': ['block.upi', 'block.card', 'block.cod'],
            'preferences': {'show_default_blocks': false}
          }
        },
      };

      _razorpay!.open(options);
    } catch (e) {
      setState(() {
        _message = e.toString();
        _loading = false;
      });
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final result = await _api.verifyPayment(
        razorpayOrderId: response.orderId!,
        razorpayPaymentId: response.paymentId!,
        razorpaySignature: response.signature!,
      );

      setState(() {
        _loading = false;
        _success = true;
        _paymentResult = result;
        _message = result['message'];
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _message = 'Verification failed: ${e.toString()}';
      });
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() {
      _loading = false;
      _message = 'Payment failed: ${response.message}';
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() {
      _loading = false;
      _message = 'Wallet: ${response.walletName}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_success && _paymentResult != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.success.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Successful',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _message ?? '',
                      style: const TextStyle(
                        color: AppTheme.textSec,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _EscrowBadge(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          final user = context.read<AuthProvider>().user;
                          if (user == null) return;
                          try {
                            final r = await _api.confirmDelivery(
                              _paymentResult!['orderId'],
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(r['message'] ?? ''),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                            Navigator.pop(context);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppTheme.danger,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'I Received the Item',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _description,
                          style: const TextStyle(
                            color: AppTheme.textPrim,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        'Rs ${_payableAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.border, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(color: AppTheme.textSec),
                      ),
                      Text(
                        'Rs ${_payableAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppTheme.textPrim,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _EscrowInfoCard(),
            const SizedBox(height: 16),
            if (_message != null && !_success)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.danger.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppTheme.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          color: AppTheme.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_message != null && !_success) const SizedBox(height: 16),
            if (!_success)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_rounded, size: 20),
                  label: Text(
                    _loading
                        ? 'Processing...'
                        : 'Pay Rs ${_payableAmount.toStringAsFixed(0)} Securely',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _loading ? null : _startPayment,
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Pay via: ',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                ...['UPI', 'Card', 'Netbanking'].map(
                  (method) => Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surface2,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.border2),
                    ),
                    child: Text(
                      method,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _EscrowBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, color: AppTheme.accentH, size: 14),
          SizedBox(width: 6),
          Text(
            'Held in Escrow - Safe',
            style: TextStyle(
              color: AppTheme.accentH,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EscrowInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00D4AA).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D4AA).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Escrow Protected',
            style: TextStyle(
              color: AppTheme.accent2,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '1. You pay and the money is held in escrow.',
            style: TextStyle(color: AppTheme.textSec, fontSize: 12),
          ),
          Text(
            '2. Seller delivers the item to you.',
            style: TextStyle(color: AppTheme.textSec, fontSize: 12),
          ),
          Text(
            '3. You confirm receipt and the seller gets paid.',
            style: TextStyle(color: AppTheme.textSec, fontSize: 12),
          ),
          Text(
            '4. If there is an issue, raise a dispute for admin review.',
            style: TextStyle(color: AppTheme.textSec, fontSize: 12),
          ),
          Text(
            '5. Escrow auto-releases after 48 hours.',
            style: TextStyle(color: AppTheme.textSec, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
