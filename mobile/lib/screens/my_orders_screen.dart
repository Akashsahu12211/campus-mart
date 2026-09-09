import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/payment_order_model.dart';
import '../providers/auth_provider.dart';
import '../providers/payment_provider.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({Key? key}) : super(key: key);

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _statusTabController;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _statusTabController = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  void _loadOrders() {
    final authProvider = context.read<AuthProvider>();
    final paymentProvider = context.read<PaymentProvider>();

    if (authProvider.user != null) {
      paymentProvider.loadBuyerOrders(authProvider.user!.id);
      paymentProvider.loadSellerOrders(authProvider.user!.id);
    }
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _statusTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          elevation: 0,
          bottom: TabBar(
            controller: _mainTabController,
            tabs: const [
              Tab(text: 'Buying'),
              Tab(text: 'Selling'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _mainTabController,
          children: [
            _buildBuyingTab(),
            _buildSellingTab(),
          ],
        ),
      ),
    );
  }

  // ── BUYING TAB ──────────────────────────────────────────────
  Widget _buildBuyingTab() {
    return Consumer<PaymentProvider>(
      builder: (context, paymentProvider, _) {
        if (paymentProvider.isLoadingBuyerOrders) {
          return const Center(child: CircularProgressIndicator());
        }

        if (paymentProvider.buyerOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No orders yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildStatsRow(paymentProvider.getBuyerStats()),
            DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  TabBar(
                    tabs: const [
                      Tab(text: 'Completed'),
                      Tab(text: 'Pending'),
                      Tab(text: 'Failed'),
                      Tab(text: 'Cancelled'),
                    ],
                    isScrollable: true,
                  ),
                  SizedBox(
                    height: 400,
                    child: TabBarView(
                      children: [
                        _buildOrdersList(
                          paymentProvider.completedBuyerOrders,
                          isBuyer: true,
                        ),
                        _buildOrdersList(
                          paymentProvider.pendingBuyerOrders,
                          isBuyer: true,
                        ),
                        _buildOrdersList(
                          paymentProvider.failedBuyerOrders,
                          isBuyer: true,
                        ),
                        _buildOrdersList(
                          paymentProvider.cancelledBuyerOrders,
                          isBuyer: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── SELLING TAB ─────────────────────────────────────────────
  Widget _buildSellingTab() {
    return Consumer<PaymentProvider>(
      builder: (context, paymentProvider, _) {
        if (paymentProvider.isLoadingSellerOrders) {
          return const Center(child: CircularProgressIndicator());
        }

        if (paymentProvider.sellerOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.sell_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No sales yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildStatsRow(paymentProvider.getSellerStats()),
            DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    tabs: const [
                      Tab(text: 'Completed'),
                      Tab(text: 'Pending'),
                      Tab(text: 'Failed'),
                    ],
                    isScrollable: true,
                  ),
                  SizedBox(
                    height: 400,
                    child: TabBarView(
                      children: [
                        _buildOrdersList(
                          paymentProvider.completedSellerOrders,
                          isBuyer: false,
                        ),
                        _buildOrdersList(
                          paymentProvider.pendingSellerOrders,
                          isBuyer: false,
                        ),
                        _buildOrdersList(
                          paymentProvider.failedSellerOrders,
                          isBuyer: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── STATS ROW ───────────────────────────────────────────────
  Widget _buildStatsRow(Map<String, int> stats) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard('Total', stats['total']!, Colors.blue),
          _buildStatCard('Completed', stats['completed']!, Colors.green),
          _buildStatCard('Pending', stats['pending']!, Colors.orange),
          _buildStatCard('Failed', stats['failed']!, Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  // ── ORDERS LIST ─────────────────────────────────────────────
  Widget _buildOrdersList(List<PaymentOrder> orders, {required bool isBuyer}) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          'No ${isBuyer ? 'purchases' : 'sales'} in this category',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(context, order, isBuyer);
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    PaymentOrder order,
    bool isBuyer,
  ) {
    final amountLabel = _formatCurrency(
      isBuyer ? order.grossAmount : order.sellerNet,
    );
    final counterpartyLabel = isBuyer
        ? (order.sellerName?.isNotEmpty == true ? order.sellerName! : 'Seller')
        : (order.buyerName?.isNotEmpty == true ? order.buyerName! : 'Buyer');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.id}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusBadge(order.status),
              ],
            ),
            const SizedBox(height: 12),

            // ── Details ──
            Text(
              '₹${order.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            if (order.itemTitle.isNotEmpty) ...[
              Text(
                order.itemTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (!isBuyer)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Seller net: $amountLabel',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date: ${_formatDate(order.createdAt)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  '${isBuyer ? 'Seller' : 'Buyer'}: $counterpartyLabel',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Notes ──
            if (_showMonetizationDetails(order)) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B4BFF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF5B4BFF).withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBuyer
                          ? 'Marketplace Protection'
                          : 'Monetization Breakdown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildAmountRow(
                      'Order gross',
                      _formatCurrency(order.grossAmount),
                    ),
                    _buildAmountRow(
                      order.platformFeePercent > 0
                          ? 'Platform fee (${order.platformFeePercent.toStringAsFixed(2)}%)'
                          : 'Platform fee',
                      _formatCurrency(order.platformFeeAmount),
                    ),
                    _buildAmountRow(
                      isBuyer ? 'Seller net after fee' : 'Seller net payout',
                      _formatCurrency(order.sellerNet),
                      emphasize: true,
                    ),
                    if (order.sellerSubscriptionCode.isNotEmpty)
                      _buildAmountRow(
                        'Seller plan',
                        order.sellerSubscriptionCode,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (order.notes.isNotEmpty)
              Text(
                'Notes: ${order.notes}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 12),

            // ── Actions ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<PaymentProvider>().loadOrderTimeline(order.id);
                    _showTimelineDialog(context, order.id);
                  },
                  icon: const Icon(Icons.timeline),
                  label: const Text('Timeline'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
                if (isBuyer && order.status == 'ESCROW_HOLD')
                  ElevatedButton.icon(
                    onPressed: () => _confirmDelivery(context, order),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Confirm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                if (isBuyer && order.status == 'CREATED')
                  ElevatedButton.icon(
                    onPressed: () => _cancelOrder(context, order),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                if (isBuyer && (order.status == 'PAID' || order.status == 'ESCROW_HOLD'))
                  ElevatedButton.icon(
                    onPressed: () => _raiseDispute(context, order),
                    icon: const Icon(Icons.warning),
                    label: const Text('Dispute'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── STATUS BADGE ────────────────────────────────────────────
  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case 'RELEASED':
        bgColor = Colors.green;
        textColor = Colors.white;
        icon = Icons.check_circle;
        break;
      case 'ESCROW_HOLD':
      case 'PAID':
        bgColor = Colors.orange;
        textColor = Colors.white;
        icon = Icons.hourglass_bottom;
        break;
      case 'FAILED':
      case 'DISPUTED':
        bgColor = Colors.red;
        textColor = Colors.white;
        icon = Icons.error;
        break;
      case 'CANCELLED':
        bgColor = Colors.grey;
        textColor = Colors.white;
        icon = Icons.cancel;
        break;
      case 'CREATED':
      default:
        bgColor = Colors.blue;
        textColor = Colors.white;
        icon = Icons.pending;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── DIALOG METHODS ──────────────────────────────────────────

  void _showTimelineDialog(BuildContext context, int orderId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Order #$orderId Timeline'),
          content: Consumer<PaymentProvider>(
            builder: (context, paymentProvider, _) {
              if (paymentProvider.isLoadingTimeline) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (paymentProvider.currentOrderTimeline.isEmpty) {
                return const Text('No timeline events');
              }

              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: paymentProvider.currentOrderTimeline.length,
                  itemBuilder: (context, index) {
                    final event = paymentProvider.currentOrderTimeline[index];
                    return ListTile(
                      title: Text('${event.icon} ${event.eventType}'),
                      subtitle: Text(event.description),
                      trailing: Text(
                        _formatDate(event.timestamp),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelivery(BuildContext context, PaymentOrder order) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Delivery'),
          content: const Text(
            'Have you received the item in good condition? '
            'This will release the payment to the seller.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final paymentProvider = context.read<PaymentProvider>();
                final authProvider = context.read<AuthProvider>();

                if (authProvider.user != null) {
                  final success = await paymentProvider.confirmDelivery(order.id);

                  if (success) {
                    Navigator.pop(context);
                    paymentProvider.loadBuyerOrders(authProvider.user!.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Delivery confirmed!')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(paymentProvider.errorMessage ?? 'Error')),
                    );
                  }
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _cancelOrder(BuildContext context, PaymentOrder order) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Order'),
          content: const Text('Are you sure you want to cancel this order?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () async {
                final paymentProvider = context.read<PaymentProvider>();
                final authProvider = context.read<AuthProvider>();

                if (authProvider.user != null) {
                  final success = await paymentProvider.cancelOrder(order.id);

                  if (success) {
                    Navigator.pop(context);
                    paymentProvider.loadBuyerOrders(authProvider.user!.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Order cancelled')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _raiseDispute(BuildContext context, PaymentOrder order) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Raise Dispute'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please describe the issue with this order:'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Describe the problem...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final paymentProvider = context.read<PaymentProvider>();
                final authProvider = context.read<AuthProvider>();

                if (reasonController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please describe the issue')),
                  );
                  return;
                }

                if (authProvider.user != null) {
                  final success = await paymentProvider.raiseDispute(
                    order.id,
                    reasonController.text,
                  );

                  if (success) {
                    Navigator.pop(context);
                    paymentProvider.loadBuyerOrders(authProvider.user!.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Dispute raised. We will review it shortly.'),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Raise Dispute'),
            ),
          ],
        );
      },
    );
  }

  // ── HELPER METHODS ──────────────────────────────────────────
  bool _showMonetizationDetails(PaymentOrder order) {
    return order.platformFeeAmount > 0 ||
        order.sellerNetAmount > 0 ||
        order.sellerSubscriptionCode.isNotEmpty;
  }

  Widget _buildAmountRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: emphasize ? Colors.white : const Color(0xFFA0A8C8),
              fontSize: 12,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    final normalized =
        amount % 1 == 0 ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
    return 'INR $normalized';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
