import 'package:flutter/foundation.dart';

class DictionaryViewModel extends ChangeNotifier {
  static const defaultLanguagePair = '自动识别 → 中文';

  String _languagePair = defaultLanguagePair;
  bool _isLoading = false;
  bool _hasResult = true;
  bool _isDisposed = false;

  String get languagePair => _languagePair;
  bool get isLoading => _isLoading;
  bool get hasResult => _hasResult;

  void selectLanguagePair(String languagePair) {
    if (_languagePair == languagePair) return;
    _languagePair = languagePair;
    notifyListeners();
  }

  Future<void> explain(String query) async {
    if (query.trim().isEmpty || _isLoading) return;

    _isLoading = true;
    _hasResult = false;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (_isDisposed) return;

    _isLoading = false;
    _hasResult = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
