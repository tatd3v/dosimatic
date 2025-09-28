import 'package:flutter/material.dart';

class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalCount;
  final int itemsPerPage;
  final Function(int) onPageChanged;
  final bool showPagination;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalCount,
    required this.itemsPerPage,
    required this.onPageChanged,
    this.showPagination = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showPagination) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page info
          Text(
            'Página $currentPage de ${((totalCount / itemsPerPage).ceil()).clamp(1, double.infinity).toInt()}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          // Document info (centered)
          Text(
            'Mostrando ${(currentPage - 1) * itemsPerPage + 1}-${currentPage * itemsPerPage > totalCount ? totalCount : currentPage * itemsPerPage}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          // Navigation buttons
          Row(
            children: [
              // Previous button
              ElevatedButton.icon(
                onPressed: currentPage > 1
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Anterior'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  foregroundColor: Colors.grey[700],
                  elevation: 1,
                ),
              ),
              const SizedBox(width: 8),
              // Next button
              ElevatedButton.icon(
                onPressed: currentPage < (totalCount / itemsPerPage).ceil()
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Siguiente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[100],
                  foregroundColor: Colors.teal[700],
                  elevation: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
