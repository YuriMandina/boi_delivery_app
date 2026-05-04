import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../database/db_helper.dart';
import '../utils/formatters.dart';
import '../services/printer_service.dart';

class ReciboScreen extends StatefulWidget {
  final Map<String, dynamic> venda;

  const ReciboScreen({Key? key, required this.venda}) : super(key: key);

  @override
  State<ReciboScreen> createState() => _ReciboScreenState();
}

class _ReciboScreenState extends State<ReciboScreen> {
  bool isLoading = true;
  bool isPrinting = false; 
  String reciboTexto = "";

  // Arquitetura otimizada para Bobina 80mm (Fonte A)
  final int _maxColunas = 48;
  
  final PrinterService _printerService = PrinterService();

  @override
  void initState() {
    super.initState();
    _gerarTalao();
  }

  String _formatarFracao(double valor) {
    if (valor == 0) return "";
    int inteiro = valor.truncate();
    double decimal = valor - inteiro;
    if (decimal == 0) return inteiro.toString();

    String fracaoStr = "";
    if ((decimal - 0.5).abs() < 0.001)
      fracaoStr = "1/2";
    else if ((decimal - 0.25).abs() < 0.001)
      fracaoStr = "1/4";
    else if ((decimal - 0.75).abs() < 0.001)
      fracaoStr = "3/4";
    else
      return valor.toStringAsFixed(2);

    return inteiro == 0 ? fracaoStr : "$inteiro e $fracaoStr";
  }

  Future<void> _gerarTalao() async {
    try {
      final db = await DBHelper().database;
      final int vendaId = widget.venda['id'];

      final clis = await db.query(
        'clientes',
        where: 'id = ?',
        whereArgs: [widget.venda['cliente_id']],
      );
      String nomeCliente = clis.isNotEmpty
          ? clis.first['nome'] as String
          : 'CLIENTE';

      final itens = await db.query(
        'venda_itens',
        where: 'venda_id = ?',
        whereArgs: [vendaId],
      );

      DateTime dtVenda = widget.venda['data_venda'] != null
          ? DateTime.parse(widget.venda['data_venda'])
          : DateTime.now();

      StringBuffer sb = StringBuffer();
      String sepForte = "=" * _maxColunas;
      String sepFraco = "-" * _maxColunas;

      sb.writeln(sepForte);
      sb.writeln(_centralizar("BOI DELIVERY", _maxColunas));
      sb.writeln(_centralizar("RECIBO DE VENDA", _maxColunas));
      sb.writeln(sepForte);
      sb.writeln("NOTA...: ${widget.venda['numero_nota']}");
      sb.writeln("DATA...: ${DateFormat('dd/MM/yyyy').format(dtVenda)}");
      sb.writeln("CLIENTE: $nomeCliente");
      if (widget.venda['eh_saida_avancada'] == 1) {
        sb.writeln("");
        sb.writeln(
          _centralizar("*** SAIDA DE ESTOQUE AVANCADO ***", _maxColunas),
        );
      }

      sb.writeln(sepFraco);
      // ARQUITETURA DE COLUNAS: Total 48 chars (10 + 14 + 10 + 14)
      String headerInfo =
          "${'PECAS'.padRight(10)}${'QTD(KG)'.padRight(14)}${'V.UN'.padLeft(10)}${'TOTAL'.padLeft(14)}";
      sb.writeln(headerInfo);
      sb.writeln(sepFraco);

      double totalGeral = 0.0;
      for (var item in itens) {
        final prods = await db.query(
          'produtos',
          where: 'id = ?',
          whereArgs: [item['produto_id']],
        );
        String nomeProd = prods.isNotEmpty
            ? prods.first['nome'] as String
            : 'PRODUTO';

        double kg = (item['quantidade_kg'] as num).toDouble();
        double preco = (item['preco_unitario'] as num).toDouble();
        double sub = (item['subtotal'] as num).toDouble();
        double pDouble =
            double.tryParse(
              item['quantidade_pecas'].toString().replaceAll(',', '.'),
            ) ??
            0.0;

        totalGeral += sub;

        sb.writeln(nomeProd);
        String obs = item['observacao']?.toString().trim() ?? "";
        if (obs.isNotEmpty) sb.writeln("  Lote/Obs: $obs");

        String sPc = _formatarFracao(pDouble);
        String sKg = AppFormatters.peso(kg);
        String sPr = AppFormatters.dinheiro(preco);
        String sSub = AppFormatters.dinheiro(sub);

        // Aplicação do grid matemático 48 colunas
        String linhaValores =
            "${sPc.padRight(10)}${sKg.padRight(14)}${sPr.padLeft(10)}${sSub.padLeft(14)}";
        sb.writeln(linhaValores);
      }

      sb.writeln(sepForte);
      sb.writeln(
        _alinharDuas(
          "TOTAL DA NOTA:",
          "R\$ ${AppFormatters.dinheiro(totalGeral)}",
          _maxColunas,
        ),
      );
      sb.writeln(sepForte);
      sb.writeln("\n\n${_centralizar("-" * 35, _maxColunas)}");
      sb.writeln(_centralizar("ASSINATURA DO CLIENTE", _maxColunas));

      setState(() {
        reciboTexto = sb.toString();
        isLoading = false;
      });
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  String _centralizar(String t, int tam) =>
      t.length >= tam ? t : "${' ' * ((tam - t.length) ~/ 2)}$t";
  String _alinharDuas(String e, String d, int tam) =>
      "$e${' ' * (tam - e.length - d.length)}$d";

  void _iniciarProcessoImpressao() async {
    setState(() => isPrinting = true);
    
    List<BluetoothDevice> dispositivos = await _printerService.obterDispositivos();
    
    setState(() => isPrinting = false);

    if (dispositivos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Nenhuma impressora Bluetooth pareada no tablet.", style: TextStyle(fontSize: 16)),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (mounted) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Selecione a Impressora",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: dispositivos.length,
                    itemBuilder: (context, index) {
                      final device = dispositivos[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const Icon(Icons.print, size: 36, color: Colors.blueGrey),
                          title: Text(device.name ?? "Dispositivo Desconhecido", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          subtitle: Text(device.address ?? ""),
                          onTap: () {
                            Navigator.pop(ctx);
                            _conectarEImprimir(device);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Future<void> _conectarEImprimir(BluetoothDevice device) async {
    setState(() => isPrinting = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(width: 16),
            Text("Conectando a ${device.name}..."),
          ],
        ),
        duration: const Duration(days: 1),
        backgroundColor: Colors.blueGrey,
      ),
    );

    bool sucessoConexao = await _printerService.conectar(device);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (!sucessoConexao) {
      setState(() => isPrinting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Falha ao conectar. Impressora ligada?"), backgroundColor: Colors.red),
        );
      }
      return;
    }

    bool sucessoImpressao = await _printerService.imprimirTexto(reciboTexto);
    await _printerService.desconectar();
    
    setState(() => isPrinting = false);

    if (sucessoImpressao) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impressão enviada com sucesso!"), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao enviar dados para impressão."), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nota ${widget.venda['numero_nota']}'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[300],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Text(
                      reciboTexto,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isPrinting ? null : _iniciarProcessoImpressao,
        icon: isPrinting 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
            : const Icon(Icons.print),
        label: Text(isPrinting ? "PROCESSANDO..." : "IMPRIMIR"),
        backgroundColor: isPrinting ? Colors.grey : Colors.blueGrey[900],
      ),
    );
  }
}