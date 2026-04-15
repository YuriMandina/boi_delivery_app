import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/db_helper.dart';

class ApiService {
  // ATENÇÃO: Substitua pela URL real do seu sistema no Render se necessário
  // static const String baseUrl = 'https://boidelivery.onrender.com/api/mobile';
  static const String baseUrl =
      'http://sdfje-45-71-111-66.run.pinggy-free.link/api/mobile';
  static const String token = 'Bearer ADM159010adm';

  // --- Função que baixa os dados da nuvem e salva no tablet ---
  static Future<bool> sincronizarDados() async {
    try {
      final db = await DBHelper().database;

      print("🌍 Tentando conectar na API: $baseUrl/produtos");
      final resProd = await http.get(
        Uri.parse('$baseUrl/produtos'),
        headers: {'Authorization': token},
      );

      print("📦 Resposta Produtos (Status): ${resProd.statusCode}");

      if (resProd.statusCode == 200) {
        final data = json.decode(resProd.body);
        if (data['success'] == true) {
          await db.delete('produtos');
          for (var p in data['produtos']) {
            await db.insert('produtos', p);
          }
          print("✅ Produtos salvos no banco offline!");
        }
      } else {
        print("❌ Erro ao baixar produtos. Token ou URL incorretos?");
        return false;
      }

      print("🌍 Tentando conectar na API: $baseUrl/clientes");
      final resCli = await http.get(
        Uri.parse('$baseUrl/clientes'),
        headers: {'Authorization': token},
      );

      print("👤 Resposta Clientes (Status): ${resCli.statusCode}");

      if (resCli.statusCode == 200) {
        final data = json.decode(resCli.body);
        if (data['success'] == true) {
          await db.delete('clientes');
          for (var c in data['clientes']) {
            await db.insert('clientes', c);
          }
          print("✅ Clientes salvos no banco offline!");
        }
      }
      return true;
    } catch (e) {
      print("🚨 ERRO GRAVE DE CONEXÃO: $e");
      return false;
    }
  }

  // --- ENVIAR VENDAS PARA O SERVIDOR (EM LOTE) ---
  static Future<int> enviarVendasPendentes() async {
    final db = await DBHelper().database;
    final vendasPendentes = await db.query(
      'vendas',
      where: 'status_sincronizacao = ?',
      whereArgs: ['pendente'],
    );

    int enviadasComSucesso = 0;

    for (var venda in vendasPendentes) {
      final itens = await db.query(
        'venda_itens',
        where: 'venda_id = ?',
        whereArgs: [venda['id']],
      );

      List<Map<String, dynamic>> itensPayload = [];
      for (var item in itens) {
        itensPayload.add({
          "produto_id": item['produto_id'],
          "quantidade": item['quantidade_kg'],
          "preco_unitario": item['preco_unitario'],
          "pecas": item['quantidade_pecas'] ?? "",
          "observacao":
              item['observacao'] ?? "", // Campo obrigatório adicionado!
        });
      }

      final payload = {
        "cliente_id": venda['cliente_id'],
        "numero_nota": venda['numero_nota'],
        "eh_saida_avancada": venda['eh_saida_avancada'] == 1,
        "itens": itensPayload,
      };

      try {
        print(
          "🚀 [LOTE] Enviando nota ${venda['numero_nota']} para o Render...",
        );

        final response = await http.post(
          Uri.parse('$baseUrl/vendas'),
          headers: {'Authorization': token, 'Content-Type': 'application/json'},
          body: json.encode(payload),
        );

        if (response.statusCode == 201) {
          await db.update(
            'vendas',
            {'status_sincronizacao': 'sincronizada'},
            where: 'id = ?',
            whereArgs: [venda['id']],
          );
          enviadasComSucesso++;
          print("✅ Nota ${venda['numero_nota']} sincronizada com sucesso!");
        } else {
          print(
            "❌ [LOTE] Erro ao enviar nota: ${response.statusCode} - ${response.body}",
          );
        }
      } catch (e) {
        print("🚨 [LOTE] Sem internet ou servidor dormindo: $e");
      }
    }
    return enviadasComSucesso;
  }

  // --- ENVIAR UMA ÚNICA VENDA (AGORA COM LOGS CORRETOS) ---
  static Future<bool> enviarVendaUnica(int vendaId) async {
    final db = await DBHelper().database;
    final vendas = await db.query(
      'vendas',
      where: 'id = ?',
      whereArgs: [vendaId],
    );
    if (vendas.isEmpty) return false;
    final venda = vendas.first;

    final itens = await db.query(
      'venda_itens',
      where: 'venda_id = ?',
      whereArgs: [vendaId],
    );

    List<Map<String, dynamic>> itensPayload = [];
    for (var item in itens) {
      itensPayload.add({
        "produto_id": item['produto_id'],
        "quantidade": item['quantidade_kg'],
        "preco_unitario": item['preco_unitario'],
        "pecas": item['quantidade_pecas'] ?? "",
        "observacao": item['observacao'] ?? "", // Campo obrigatório adicionado!
      });
    }

    final payload = {
      "cliente_id": venda['cliente_id'],
      "numero_nota": venda['numero_nota'],
      "eh_saida_avancada": venda['eh_saida_avancada'] == 1,
      "itens": itensPayload,
    };

    try {
      print(
        "🚀 [INDIVIDUAL] Enviando nota ${venda['numero_nota']} para o Render...",
      );

      final response = await http.post(
        Uri.parse('$baseUrl/vendas'),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      print(
        "📦 [INDIVIDUAL] Resposta API: ${response.statusCode} - ${response.body}",
      );

      if (response.statusCode == 201) {
        await db.update(
          'vendas',
          {'status_sincronizacao': 'sincronizada'},
          where: 'id = ?',
          whereArgs: [vendaId],
        );
        print("✅ Nota ${venda['numero_nota']} sincronizada com sucesso!");
        return true;
      } else {
        print("❌ [INDIVIDUAL] Falha no ERP: ${response.body}");
      }
    } catch (e) {
      print("🚨 [INDIVIDUAL] Erro Crítico (Internet/Servidor): $e");
    }
    return false;
  }
}
