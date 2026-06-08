import 'package:intl/intl.dart';

class CurrencyUtil {
  static const Map<String, String> _currencySymbols = {
    'USD': r'$',
    'EUR': r'€',
    'GBP': r'£',
    'EGP': r'E£',
    'SAR': r'SR',
    'AED': r'د.إ',
  };

  static String getSymbol(String? currencyCode) {
    return _currencySymbols[currencyCode] ?? r'$';
  }

  static NumberFormat getFormat(String? currencyCode) {
    final symbol = getSymbol(currencyCode);
    return NumberFormat.currency(symbol: symbol, name: currencyCode ?? 'USD');
  }

  static String getPrefixText(String? currencyCode) {
    return '${getSymbol(currencyCode)} ';
  }
}
