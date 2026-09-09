import 'package:flutter/material.dart';
import '../models/payment_order_model.dart';
import '../models/timeline_event_model.dart';
import '../services/api_service.dart';

class PaymentProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // ── State Variables ────────────────────────────────────────
  List<PaymentOrder> _buyerOrders = [];
  List<PaymentOrder> _sellerOrders = [];
  List<TimelineEvent> _currentOrderTimeline = [];
  
  bool _isLoadingBuyerOrders = false;
  bool _isLoadingSellerOrders = false;
  bool _isLoadingTimeline = false;
  
  String? _errorMessage;

  // ── Getters ────────────────────────────────────────────────
  List<PaymentOrder> get buyerOrders => _buyerOrders;
  List<PaymentOrder> get sellerOrders => _sellerOrders;
  List<TimelineEvent> get currentOrderTimeline => _currentOrderTimeline;
  
  bool get isLoadingBuyerOrders => _isLoadingBuyerOrders;
  bool get isLoadingSellerOrders => _isLoadingSellerOrders;
  bool get isLoadingTimeline => _isLoadingTimeline;
  
  String? get errorMessage => _errorMessage;

  // ── Filter Helpers ────────────────────────────────────────
  List<PaymentOrder> get completedBuyerOrders =>
      _buyerOrders.where((o) => o.isCompleted).toList();
  
  List<PaymentOrder> get pendingBuyerOrders =>
      _buyerOrders.where((o) => o.isPending).toList();
  
  List<PaymentOrder> get failedBuyerOrders =>
      _buyerOrders.where((o) => o.isFailed).toList();
  
  List<PaymentOrder> get cancelledBuyerOrders =>
      _buyerOrders.where((o) => o.isCancelled).toList();

  List<PaymentOrder> get completedSellerOrders =>
      _sellerOrders.where((o) => o.isCompleted).toList();
  
  List<PaymentOrder> get pendingSellerOrders =>
      _sellerOrders.where((o) => o.isPending).toList();
  
  List<PaymentOrder> get failedSellerOrders =>
      _sellerOrders.where((o) => o.isFailed).toList();

  // ── Stats ──────────────────────────────────────────────────
  Map<String, int> getBuyerStats() {
    return {
      'total': _buyerOrders.length,
      'completed': completedBuyerOrders.length,
      'pending': pendingBuyerOrders.length,
      'failed': failedBuyerOrders.length,
      'cancelled': cancelledBuyerOrders.length,
    };
  }

  Map<String, int> getSellerStats() {
    return {
      'total': _sellerOrders.length,
      'completed': completedSellerOrders.length,
      'pending': pendingSellerOrders.length,
      'failed': failedSellerOrders.length,
    };
  }

  double getTotalBuyerSpend() {
    return completedBuyerOrders.fold(0.0, (sum, order) => sum + order.amount);
  }

  double getTotalSellerRevenue() {
    return completedSellerOrders.fold(0.0, (sum, order) => sum + order.sellerNet);
  }

  // ── Methods ────────────────────────────────────────────────

  Future<void> loadBuyerOrders(int buyerId) async {
    _isLoadingBuyerOrders = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getBuyerOrders(buyerId);
      _buyerOrders = response
          .map((item) => PaymentOrder.fromJson(item))
          .toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _buyerOrders = [];
    } finally {
      _isLoadingBuyerOrders = false;
      notifyListeners();
    }
  }

  Future<void> loadSellerOrders(int sellerId) async {
    _isLoadingSellerOrders = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getSellerOrders(sellerId);
      _sellerOrders = response
          .map((item) => PaymentOrder.fromJson(item))
          .toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _sellerOrders = [];
    } finally {
      _isLoadingSellerOrders = false;
      notifyListeners();
    }
  }

  Future<void> loadOrderTimeline(int orderId) async {
    _isLoadingTimeline = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getOrderTimeline(orderId);
      _currentOrderTimeline = response
          .map((item) => TimelineEvent.fromJson(item))
          .toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _currentOrderTimeline = [];
    } finally {
      _isLoadingTimeline = false;
      notifyListeners();
    }
  }

  Future<bool> confirmDelivery(int orderId) async {
    try {
      await _apiService.confirmDelivery(orderId);
      // Update local state
      final index = _buyerOrders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _buyerOrders[index] = _buyerOrders[index]; // Trigger refresh by reloading
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> raiseDispute(int orderId, String reason) async {
    try {
      await _apiService.raiseDispute(orderId, reason);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelOrder(int orderId) async {
    try {
      await _apiService.cancelOrder(orderId);
      // Update local state
      final index = _buyerOrders.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        _buyerOrders.removeAt(index);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
