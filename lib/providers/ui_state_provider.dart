import 'package:flutter/foundation.dart';

/// UI State Provider for managing loading and error states
class UiStateProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  /// Show loading state
  void setLoading(bool value) {
    _isLoading = value;
    if (value) {
      _errorMessage = null;
      _successMessage = null;
    }
    notifyListeners();
  }

  /// Show error message
  void setError(String? message) {
    _errorMessage = message;
    _isLoading = false;
    _successMessage = null;
    notifyListeners();
  }

  /// Show success message
  void setSuccess(String? message) {
    _successMessage = message;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear all messages and loading state
  void clear() {
    _isLoading = false;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Reset error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Reset success message
  void clearSuccess() {
    _successMessage = null;
    notifyListeners();
  }
}

/// Enum for result status
enum ResultStatus { idle, loading, success, error }

/// Generic Result class for async operations
class Result<T> {
  final ResultStatus status;
  final T? data;
  final String? error;

  Result({
    required this.status,
    this.data,
    this.error,
  });

  factory Result.idle() => Result(status: ResultStatus.idle);
  factory Result.loading() => Result(status: ResultStatus.loading);
  factory Result.success(T data) => Result(status: ResultStatus.success, data: data);
  factory Result.error(String error) => Result(status: ResultStatus.error, error: error);

  bool get isLoading => status == ResultStatus.loading;
  bool get isSuccess => status == ResultStatus.success;
  bool get isError => status == ResultStatus.error;
  bool get isIdle => status == ResultStatus.idle;
}
