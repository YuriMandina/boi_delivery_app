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

  // MÁSCARA MATEMÁTICA: Resolve o bug de floating point do Dart
  static String pecasTratadas(double valor, {bool exibirTextoZero = false, bool usarE = false}) {
    if (valor <= 0) return exibirTextoZero ? "Nenhuma" : "";

    int inteiro = valor.truncate();
    
    // Arredonda explicitamente a diferença decimal para não cair na armadilha do ponto flutuante
    double decimal = double.parse((valor - inteiro).toStringAsFixed(3));

    if (decimal == 0) return inteiro.toString();

    String fracaoStr = "";
    if ((decimal - 0.5).abs() < 0.001) {
      fracaoStr = "1/2";
    } else if ((decimal - 0.25).abs() < 0.001) {
      fracaoStr = "1/4";
    } else if ((decimal - 0.75).abs() < 0.001) {
      fracaoStr = "3/4";
    } else {
      return valor.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    }

    if (inteiro == 0) return fracaoStr;
    
    // Permite usar "1 e 1/2" (Recibo) ou "1 1/2" (Venda Screen)
    return usarE ? "$inteiro e $fracaoStr" : "$inteiro $fracaoStr";
  }
}