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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: DesignSystem.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Log Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showLogExpenseBottomSheet(context),
      ),
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
    final isExpense = tx.transactionType == 'expense';
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
          backgroundColor: (isExpense ? DesignSystem.error : DesignSystem.primary).withValues(alpha: 0.1),
          child: Text(
            tx.sender.isNotEmpty ? tx.sender[0].toUpperCase() : '?',
            style: TextStyle(color: isExpense ? DesignSystem.error : DesignSystem.primary, fontWeight: FontWeight.bold),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tx.date.substring(0, 10),
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            if (tx.classification != null)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: (isExpense ? DesignSystem.error : DesignSystem.primary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tx.classification!,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: isExpense ? DesignSystem.error : DesignSystem.primary,
                  ),
                ),
              ),
          ],
        ),
        trailing: Text(
          isExpense ? '-₹${amt.toStringAsFixed(2)}' : '+₹${amt.toStringAsFixed(2)}',
          style: TextStyle(
            color: isExpense ? DesignSystem.error : DesignSystem.success,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  void _showLogExpenseBottomSheet(BuildContext context) {
    final amountController = TextEditingController();
    final payeeController = TextEditingController();
    final notesController = TextEditingController();
    String category = 'Fuel / Commute';
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDark ? DesignSystem.backgroundDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + DesignSystem.lg,
                left: DesignSystem.lg,
                right: DesignSystem.lg,
                top: DesignSystem.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log Business Expense',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _isDark ? Colors.white : Colors.black87,
                          ),
                    ),
                    const SizedBox(height: DesignSystem.md),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: _isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Amount (INR)',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: DesignSystem.md),
                    TextField(
                      controller: payeeController,
                      style: TextStyle(color: _isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Merchant / Payee',
                        hintText: 'e.g. Shell Petrol Pump, Uber Fees',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: DesignSystem.md),
                    DropdownButtonFormField<String>(
                      value: category,
                      dropdownColor: _isDark ? DesignSystem.backgroundDark : Colors.white,
                      style: TextStyle(color: _isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Expense Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Fuel / Commute', child: Text('Fuel / Commute')),
                        DropdownMenuItem(value: 'Platform Commissions', child: Text('Platform Commissions')),
                        DropdownMenuItem(value: 'Mobile / Internet Bill', child: Text('Mobile / Internet Bill')),
                        DropdownMenuItem(value: 'Rent / Workspace', child: Text('Rent / Workspace')),
                        DropdownMenuItem(value: 'Supplies / Hardware', child: Text('Supplies / Hardware')),
                        DropdownMenuItem(value: 'Other Business Expense', child: Text('Other Business Expense')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => category = val);
                        }
                      },
                    ),
                    const SizedBox(height: DesignSystem.md),
                    TextField(
                      controller: notesController,
                      style: TextStyle(color: _isDark ? Colors.white : Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Notes / Description (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: DesignSystem.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Date: ${selectedDate.toLocal().toString().substring(0, 10)}',
                          style: TextStyle(color: _isDark ? Colors.white70 : Colors.black87),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => selectedDate = picked);
                            }
                          },
                          child: const Text('Change Date'),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignSystem.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignSystem.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          if (amountController.text.isEmpty || payeeController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill out Amount and Merchant fields.')),
                            );
                            return;
                          }
                          final tx = Transaction(
                            amount: amountController.text,
                            sender: payeeController.text,
                            messageBody: notesController.text.isNotEmpty
                                ? notesController.text
                                : 'Manual expense: $category',
                            transactionType: 'expense',
                            date: selectedDate.toIso8601String(),
                            classification: category,
                            confidence: 1.0,
                            source: payeeController.text,
                          );

                          await DatabaseService.insertTransaction(tx);
                          try {
                            await _firestore.addTransaction(tx).timeout(const Duration(seconds: 2));
                          } catch (_) {}

                          if (context.mounted) {
                            Navigator.pop(context);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Expense logged successfully!')),
                            );
                          }
                        },
                        child: const Text('Save Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
