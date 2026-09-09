// lib/widgets/pagination_controls.dart

import 'package:flutter/material.dart';

class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final String sortBy;
  final Function(int) onPageChanged;
  final Function(String) onSortChanged;

  const PaginationControls({
    Key? key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.sortBy,
    required this.onPageChanged,
    required this.onSortChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1419),
        border: Border(
          top: BorderSide(color: const Color(0xFF2D3748)),
        ),
      ),
      child: Column(
        children: [
          // Sort Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sort by:',
                style: TextStyle(
                  color: Color(0xFFA0AEC0),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2D3748)),
                ),
                child: DropdownButton<String>(
                  value: sortBy,
                  isDense: true,
                  dropdownColor: const Color(0xFF1A1F2E),
                  style: const TextStyle(
                    color: Color(0xFF5B4BFF),
                    fontWeight: FontWeight.w600,
                  ),
                  underline: const SizedBox(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      onSortChanged(newValue);
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: 'newest',
                      child: const Text('Newest First'),
                    ),
                    DropdownMenuItem(
                      value: 'price_low',
                      child: const Text('Price: Low to High'),
                    ),
                    DropdownMenuItem(
                      value: 'price_high',
                      child: const Text('Price: High to Low'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pagination Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2D3748)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page ${currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                  style: const TextStyle(
                    color: Color(0xFFA0AEC0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Total: $totalItems items',
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Previous/Next Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: currentPage > 0
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B4BFF),
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2D3748)),
                ),
                child: Text(
                  '${currentPage + 1}',
                  style: const TextStyle(
                    color: Color(0xFF5B4BFF),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: currentPage < totalPages - 1
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B4BFF),
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
