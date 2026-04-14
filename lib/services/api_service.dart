import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/db_helper.dart';

class ApiService {
  // ATENÇÃO: Substitua pela URL real do seu sistema no Render
  static const String baseUrl = 'https://boidelivery.onrender.com/api/mobile';

  // ATENÇÃO: Substitua pela chave que você configurou no .env do Render (MOBILE_API_TOKEN)
  static const String token = 'Bearer ADM159010adm';

  // Função que baixa os dados da nuvem e salva no tablet
  static Future<bool> sincronizarDados() async {
    try {
      final db = await DBHelper().database;

      print("🌍 Tentando conectar na API: $baseUrl/produtos");

      // 1. Baixar Produtos
      final resProd = await http.get(
        Uri.parse('$baseUrl/produtos'),
        headers: {'Authorization': token},
      );

      print("📦 Resposta Produtos (Status): ${resProd.statusCode}");
      print("📦 Corpo da Resposta: ${resProd.body}");

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

      // 2. Baixar Clientes
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

  // --- ENVIAR VENDAS PARA O SERVIDOR ---
  static Future<int> enviarVendasPendentes() async {
    final db = await DBHelper().database;

    // Busca apenas as vendas que ainda não foram enviadas
    final vendasPendentes = await db.query(
      'vendas',
      where: 'status_sincronizacao = ?',
      whereArgs: ['pendente'],
    );

    int enviadasComSucesso = 0;

    for (var venda in vendasPendentes) {
      // 1. Busca os itens dessa venda específica no banco do tablet
      final itens = await db.query(
        'venda_itens',
        where: 'venda_id = ?',
        whereArgs: [venda['id']],
      );

      // 2. Monta a lista de itens no formato exato que seu Flask (app.py) exige
      List<Map<String, dynamic>> itensPayload = [];
      for (var item in itens) {
        itensPayload.add({
          "produto_id": item['produto_id'],
          "quantidade": item['quantidade_kg'], // Peso
          "preco_unitario": item['preco_unitario'],
          "pecas": item['quantidade_pecas'] ?? "", // Fração (Opcional)
        });
      }

      // 3. Monta o pacote da Venda (A Capa)
      final payload = {
        "cliente_id": venda['cliente_id'],
        "numero_nota": venda['numero_nota'],
        "eh_saida_avancada":
            venda['eh_saida_avancada'] ==
            1, // Converte 1/0 do SQLite para True/False
        "itens": itensPayload,
      };

      try {
        print("🚀 Enviando nota ${venda['numero_nota']} para o Render...");

        // 4. Dispara para a rota POST /vendas do seu backend
        final response = await http.post(
          Uri.parse('$baseUrl/vendas'),
          headers: {'Authorization': token, 'Content-Type': 'application/json'},
          body: json.encode(payload),
        );

        // 5. Se o Flask respondeu 201 (Created)
        if (response.statusCode == 201) {
          // Muda o status no tablet para não enviar duplicado no futuro
          await db.update(
            'vendas',
            {'status_sincronizacao': 'sincronizada'},
            where: 'id = ?',
            whereArgs: [venda['id']],
          );
          enviadasComSucesso++;
          print("✅ Nota ${venda['numero_nota']} sincronizada com sucesso!");
        } else {
          print("❌ Erro ao enviar nota: ${response.body}");
        }
      } catch (e) {
        print("🚨 Sem internet ou servidor dormindo: $e");
      }
    }
    return enviadasComSucesso; // Retorna quantas notas foram pro escritório
  }

  // --- NOVO: ENVIAR UMA ÚNICA VENDA ---
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
        "observacao": item['observacao'] ?? "",
      });
    }

    final payload = {
      "cliente_id": venda['cliente_id'],
      "numero_nota": venda['numero_nota'],
      "eh_saida_avancada": venda['eh_saida_avancada'] == 1,
      "itens": itensPayload,
    };

    try {
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
          whereArgs: [vendaId],
        );
        return true;
      }
    } catch (e) {
      print("Erro ao enviar venda única: $e");
    }
    return false;
  }
}
