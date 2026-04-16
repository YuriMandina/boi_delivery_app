// lib/utils/formatters.dart
import 'package:intl/intl.dart';

class AppFormatters {
  // Formata valores monetários: 230000.0 -> 230.000,00
  static String dinheiro(double valor) {
    return NumberFormat('#,##0.00', 'pt_BR').format(valor);
  }

  // Formata pesos com 3 CASAS DECIMAIS: 10000.0 -> 10.000,000
  static String peso(double valor) {
    return NumberFormat('#,##0.000', 'pt_BR').format(valor);
  }
}
