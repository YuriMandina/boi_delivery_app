import 'package:flutter/material.dart';

class TecladoNumerico extends StatefulWidget {
  final String titulo;
  final Function(double) onConfirmar;

  const TecladoNumerico({
    Key? key,
    required this.titulo,
    required this.onConfirmar,
  }) : super(key: key);

  @override
  State<TecladoNumerico> createState() => _TecladoNumericoState();
}

class _TecladoNumericoState extends State<TecladoNumerico> {
  String valor = "0";

  void _teclar(String tecla) {
    setState(() {
      if (tecla == "C") {
        valor = "0"; // Limpa tudo
      } else if (tecla == "<") {
        valor = valor.length > 1
            ? valor.substring(0, valor.length - 1)
            : "0"; // Apaga um
      } else if (tecla == ",") {
        if (!valor.contains(",")) valor += ","; // Evita duas vírgulas
      } else {
        valor = valor == "0" ? tecla : valor + tecla; // Adiciona número
      }
    });
  }

  // Criador de botões gigantes
  Widget _buildBotao(String texto, {Color? cor, Color? corTexto}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: cor ?? Colors.grey[200],
            foregroundColor: corTexto ?? Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () => _teclar(texto),
          child: texto == "<"
              ? const Icon(Icons.backspace, size: 36)
              : Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 550, // Altura perfeita para tablet
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Text(
            widget.titulo,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 16),
          // Visor do valor
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue, width: 3),
            ),
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          // Matriz do Teclado
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildBotao("7"),
                      _buildBotao("8"),
                      _buildBotao("9"),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildBotao("4"),
                      _buildBotao("5"),
                      _buildBotao("6"),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildBotao("1"),
                      _buildBotao("2"),
                      _buildBotao("3"),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildBotao(
                        "C",
                        cor: Colors.red[100],
                        corTexto: Colors.red,
                      ),
                      _buildBotao("0"),
                      _buildBotao(","),
                      _buildBotao("<", cor: Colors.grey[300]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Botão Confirmar
          SizedBox(
            width: double.infinity,
            height: 80,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                // Converte a string "12,5" para o double 12.5 que o banco aceita
                double numFinal =
                    double.tryParse(valor.replaceAll(",", ".")) ?? 0.0;
                widget.onConfirmar(numFinal);
                Navigator.pop(context); // Fecha o teclado
              },
              child: const Text(
                "CONFIRMAR VALOR",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
