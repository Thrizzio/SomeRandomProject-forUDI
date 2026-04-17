import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/bank_statement_parser.dart';
import '../services/bank_statement_service.dart';

class BankStatementUploadDialog extends StatefulWidget {
  final Function(int) onUploadComplete;

  const BankStatementUploadDialog({
    super.key,
    required this.onUploadComplete,
  });

  @override
  State<BankStatementUploadDialog> createState() =>
      _BankStatementUploadDialogState();
}

class _BankStatementUploadDialogState extends State<BankStatementUploadDialog> {
  String? _selectedFile;
  String? _selectedOrganization;
  bool _isLoading = false;
  bool _showCustomOrgInput = false;
  final _customOrgController = TextEditingController();

  static const List<String> predefinedOrganizations = [
    'Swiggy',
    'Zomato',
    'Ola',
    'Zepto',
  ];

  @override
  void dispose() {
    _customOrgController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls', 'pdf', 'txt'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.single.path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _uploadAndProcess() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file')),
      );
      return;
    }

    if (_selectedOrganization == null && !_showCustomOrgInput) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an organization')),
      );
      return;
    }

    if (_showCustomOrgInput && _customOrgController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter organization name')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final organization = _showCustomOrgInput
          ? _customOrgController.text.trim()
          : _selectedOrganization!;

      final fileName = _selectedFile!.split('/').last;

      // Parse CSV file
      final transactions = await BankStatementParser.parseCsvFile(
        _selectedFile!,
        organization,
        fileName,
      );

      debugPrint('💾 Upload Dialog: Received ${transactions.length} transactions to save');

      if (transactions.isEmpty) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No Transactions Found'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'We could not extract any transactions from this file.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please ensure your CSV file has the following format:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Row 1 (Header): Date, Description, Amount\n'
                  'Row 2+: 01/01/2024, Swiggy Payment, 500\n\n'
                  'Common issues:\n'
                  '• Missing or incorrectly formatted dates\n'
                  '• Missing amount values\n'
                  '• Less than 3 columns',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Save transactions to database
      int count = 0;
      for (final transaction in transactions) {
        await BankStatementService.insertBankStatementTransaction(transaction);
        count++;
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onUploadComplete(count);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded $count transactions')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing file: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Bank Statement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File selection
            Text(
              'Select File',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(
                _selectedFile != null
                    ? _selectedFile!.split('/').last
                    : 'Choose CSV/Excel file',
              ),
            ),
            const SizedBox(height: 16),

            // Organization selection
            Text(
              'Organization',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: _selectedOrganization,
              hint: const Text('Select organization'),
              items: [
                ...predefinedOrganizations.map((org) {
                  return DropdownMenuItem(
                    value: org,
                    child: Text(org),
                  );
                }),
                const DropdownMenuItem(
                  value: '__OTHER__',
                  child: Text('Others'),
                ),
              ],
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        if (value == '__OTHER__') {
                          _showCustomOrgInput = true;
                          _selectedOrganization = null;
                        } else {
                          _showCustomOrgInput = false;
                          _selectedOrganization = value;
                        }
                      });
                    },
            ),

            // Custom organization input
            if (_showCustomOrgInput) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customOrgController,
                decoration: InputDecoration(
                  labelText: 'Enter organization name',
                  hintText: 'e.g., MyFood, LocalDeli',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                enabled: !_isLoading,
              ),
            ],

            const SizedBox(height: 16),

            // Info text
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Supported formats: CSV, Excel (XLSX), TXT\nThe file should have columns: Date, Description, Amount',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _uploadAndProcess,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Upload'),
        ),
      ],
    );
  }
}
