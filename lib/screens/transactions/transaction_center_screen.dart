import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../services/firestore_service.dart';
import '../../services/database_service.dart';
import '../../theme/design_system.dart';

class TransactionCenterScreen extends StatefulWidget {
  const TransactionCenterScreen({super.key});

  @override
  State<TransactionCenterScreen> createState() => _TransactionCenterScreenState();
}

class _TransactionCenterScreenState extends State<TransactionCenterScreen> {
  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  String _selectedSource = 'All';
  String _selectedSort = 'Date (Newest)';
  double _minAmount = 0.0;
  bool _isDark = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Transaction>> _fetchTransactions() async {
    try {
      final firestoreTxs = await _firestore.getTransactions().timeout(
        const Duration(seconds: 2),
        onTimeout: () => [],
      );
      if (firestoreTxs.isNotEmpty) return firestoreTxs;
      return await DatabaseService.getAllTransactions();
    } catch (_) {
      return await DatabaseService.getAllTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _isDark ? DesignSystem.backgroundDark : DesignSystem.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildFiltersRow(),
            Expanded(
              child: FutureBuilder<List<Transaction>>(
                future: _fetchTransactions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: DesignSystem.primary));
                  }
                  if (snapshot.hasError) {
                    return DesignSystem.emptyState(
                      context: context,
                      title: 'Error Loading Transactions',
                      message: snapshot.error.toString(),
                      icon: Icons.error_outline,
                      isDark: _isDark,
                    );
                  }

                  final allTxs = snapshot.data ?? [];
                  final filteredTxs = _processTransactions(allTxs);

                  if (filteredTxs.isEmpty) {
                    return DesignSystem.emptyState(
                      context: context,
                      title: 'No Matching Receipts',
                      message: 'Try adjusting your search query, source, or amount thresholds.',
                      icon: Icons.search_off_outlined,
                      isDark: _isDark,
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: DesignSystem.md),
                    itemCount: filteredTxs.length,
                    itemExtent: 80, // Lock heights for high-performance viewport recycling
                    itemBuilder: (context, index) {
                      final tx = filteredTxs[index];
                      final double amtVal = double.tryParse(
                            tx.amount.replaceAll(',', '').replaceAll('INR', '').trim(),
                          ) ??
                          0.0;
                      return _buildTransactionTile(tx, amtVal);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(DesignSystem.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction Center',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _isDark ? Colors.white : Colors.black87,
                ),
          ),
          const SizedBox(height: DesignSystem.md),
          TextField(
            controller: _searchController,
            style: TextStyle(color: _isDark ? Colors.white : Colors.black87),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by client, narration or ID...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              fillColor: _isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _isDark ? Colors.white10 : Colors.grey.shade200),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: DesignSystem.md, bottom: DesignSystem.md),
      child: Row(
        children: [
          _buildFilterChip('Source: $_selectedSource', () => _showSourcePicker()),
          const SizedBox(width: DesignSystem.sm),
          _buildFilterChip('Min Amount: ₹${_minAmount.toStringAsFixed(0)}', () => _showMinAmountSlider()),
          const SizedBox(width: DesignSystem.sm),
          _buildFilterChip('Sort: $_selectedSort', () => _showSortPicker()),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      labelStyle: TextStyle(
        color: _isDark ? Colors.white70 : Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      backgroundColor: _isDark ? Colors.white10 : Colors.grey.shade100,
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  List<Transaction> _processTransactions(List<Transaction> original) {
    var result = List<Transaction>.from(original);

    // Apply Search
    if (_searchQuery.isNotEmpty) {
      result = result.where((t) {
        return t.sender.toLowerCase().contains(_searchQuery) ||
            t.messageBody.toLowerCase().contains(_searchQuery) ||
            t.amount.contains(_searchQuery);
      }).toList();
    }

    // Apply Source Filter
    if (_selectedSource != 'All') {
      result = result.where((t) => t.sender.toLowerCase() == _selectedSource.toLowerCase()).toList();
    }

    // Apply Min Amount Filter
    if (_minAmount > 0) {
      result = result.where((t) {
        final amt = double.tryParse(t.amount.replaceAll(',', '').replaceAll('INR', '').trim()) ?? 0.0;
        return amt >= _minAmount;
      }).toList();
    }

    // Apply Sorts
    if (_selectedSort == 'Date (Newest)') {
      result.sort((a, b) => b.date.compareTo(a.date));
    } else if (_selectedSort == 'Date (Oldest)') {
      result.sort((a, b) => a.date.compareTo(b.date));
    } else if (_selectedSort == 'Amount (Highest)') {
      result.sort((a, b) {
        final aVal = double.tryParse(a.amount.replaceAll(',', '').replaceAll('INR', '').trim()) ?? 0.0;
        final bVal = double.tryParse(b.amount.replaceAll(',', '').replaceAll('INR', '').trim()) ?? 0.0;
        return bVal.compareTo(aVal);
      });
    } else if (_selectedSort == 'Amount (Lowest)') {
      result.sort((a, b) {
        final aVal = double.tryParse(a.amount.replaceAll(',', '').replaceAll('INR', '').trim()) ?? 0.0;
        final bVal = double.tryParse(b.amount.replaceAll(',', '').replaceAll('INR', '').trim()) ?? 0.0;
        return aVal.compareTo(bVal);
      });
    }

    return result;
  }

  Widget _buildTransactionTile(Transaction tx, double amt) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: DesignSystem.sm),
      color: _isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: DesignSystem.primary.withValues(alpha: 0.1),
          child: Text(
            tx.sender.isNotEmpty ? tx.sender[0].toUpperCase() : '?',
            style: const TextStyle(color: DesignSystem.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          tx.sender,
          style: TextStyle(
            color: _isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          tx.date.substring(0, 10),
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        trailing: Text(
          '+₹${amt.toStringAsFixed(2)}',
          style: const TextStyle(color: DesignSystem.success, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? DesignSystem.backgroundDark : Colors.white,
      builder: (context) {
        final sources = ['All', 'Uber', 'Ola', 'Swiggy', 'Zomato', 'Zepto', 'Freelance'];
        return ListView(
          shrinkWrap: true,
          children: sources.map((s) {
            return ListTile(
              title: Text(s, style: TextStyle(color: _isDark ? Colors.white : Colors.black87)),
              onTap: () {
                setState(() => _selectedSource = s);
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _showSortPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? DesignSystem.backgroundDark : Colors.white,
      builder: (context) {
        final sorts = ['Date (Newest)', 'Date (Oldest)', 'Amount (Highest)', 'Amount (Lowest)'];
        return ListView(
          shrinkWrap: true,
          children: sorts.map((s) {
            return ListTile(
              title: Text(s, style: TextStyle(color: _isDark ? Colors.white : Colors.black87)),
              onTap: () {
                setState(() => _selectedSort = s);
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  void _showMinAmountSlider() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDark ? DesignSystem.backgroundDark : Colors.white,
      builder: (context) {
        double tempAmt = _minAmount;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(DesignSystem.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Filter by Minimum Amount',
                    style: TextStyle(
                      color: _isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: DesignSystem.md),
                  Slider(
                    value: tempAmt,
                    min: 0.0,
                    max: 50000.0,
                    divisions: 100,
                    label: '₹${tempAmt.toStringAsFixed(0)}',
                    onChanged: (val) {
                      setModalState(() => tempAmt = val);
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() => _minAmount = 0.0);
                          Navigator.pop(context);
                        },
                        child: const Text('Reset'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _minAmount = tempAmt);
                          Navigator.pop(context);
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
