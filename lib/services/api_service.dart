import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/db_helper.dart';

class ApiService {
  static const String baseUrl = 'https://boidelivery.onrender.com/api/mobile';
  static const String token = 'Bearer ADM159010adm';

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
            // ==========================================
            // B2B ARCHITECTURE: DOMAIN FALLBACK
            // ==========================================
            // Tenta ler a flag do backend (várias nomenclaturas possíveis)
            var val = p['is_produto_banda'] ?? p['isProdutoBanda'] ?? p['produto_banda'] ?? p['is_banda'];
            
            if (val != null) {
              // Se o backend enviou, confiamos cegamente na tipagem agressiva
              p['is_produto_banda'] = (val == true || val == 1 || val == '1' || val.toString().toLowerCase() == 'true') ? 1 : 0;
            } else {
              // TODO: Remover este bloco quando o backend Flask for corrigido.
              // FALLBACK: O backend falhou em enviar a flag. Vamos deduzir pelo nome para não bloquear o motorista.
              String nomeNormalizado = (p['nome'] ?? '').toString().toLowerCase();
              bool deducaoBanda = nomeNormalizado.contains('reis') || 
                                  nomeNormalizado.contains('rês') || 
                                  nomeNormalizado.contains('dianteiro') ||
                                  nomeNormalizado.contains('traseiro') ||
                                  nomeNormalizado.contains('serrote');
              
              p['is_produto_banda'] = deducaoBanda ? 1 : 0;
              print("⚠️ Backend omitiu flag para '${p['nome']}'. Fallback aplicado: ${p['is_produto_banda']}");
            }
            
            await db.insert('produtos', p);
          }
          print("✅ Produtos salvos no banco offline!");
        }
      } else {
        print("❌ Erro ao baixar produtos. Status: ${resProd.statusCode}");
        return false;
      }

      print("🌍 Tentando conectar na API: $baseUrl/clientes");
      final resCli = await http.get(
        Uri.parse('$baseUrl/clientes'),
        headers: {'Authorization': token},
      );

      if (resCli.statusCode == 200) {
        final data = json.decode(resCli.body);
        if (data['success'] == true) {
          // Apaga apenas os clientes que vieram do servidor (não os criados offline)
          await db.rawDelete(
            "DELETE FROM clientes WHERE status_sincronizacao = 'sincronizado' OR status_sincronizacao IS NULL",
          );
          for (var c in data['clientes']) {
            await db.rawInsert(
              'INSERT OR IGNORE INTO clientes (id, nome, status_sincronizacao) VALUES (?, ?, ?)',
              [c['id'], c['nome'], 'sincronizado'],
            );
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

  // --- SINCRONIZAR CLIENTES CRIADOS OFFLINE ---
  // Resolve o ForeignKeyViolation: garante que o cliente existe no Postgres
  // antes de tentar registrar a venda, e atualiza o ID local pelo ID real do servidor.
  static Future<void> _sincronizarClientesPendentes() async {
    final db = await DBHelper().database;

    final clientesPendentes = await db.query(
      'clientes',
      where: 'status_sincronizacao = ?',
      whereArgs: ['pendente'],
    );

    for (var cliente in clientesPendentes) {
      final int localId = cliente['id'] as int;

      final payload = {
        "nome": cliente['nome'],
        "cpf_cnpj": cliente['cpf_cnpj'] ?? "",
        "telefone": cliente['telefone'] ?? "",
        "email": cliente['email'] ?? "",
        "endereco": cliente['endereco'] ?? "",
      };

      try {
        print("🧑 Sincronizando cliente offline: '${cliente['nome']}' (id local: $localId)");
        final response = await http.post(
          Uri.parse('$baseUrl/clientes'),
          headers: {'Authorization': token, 'Content-Type': 'application/json'},
          body: json.encode(payload),
        );

        if (response.statusCode == 201) {
          final data = json.decode(response.body);
          final int serverId = data['cliente_id'] as int;

          // Atualiza todas as vendas que referenciam o ID local para o ID real do servidor
          await db.rawUpdate(
            'UPDATE vendas SET cliente_id = ? WHERE cliente_id = ?',
            [serverId, localId],
          );

          // Atualiza o próprio registro do cliente com o ID real
          await db.rawUpdate(
            'UPDATE clientes SET id = ?, status_sincronizacao = ? WHERE id = ?',
            [serverId, 'sincronizado', localId],
          );

          print("✅ Cliente '${cliente['nome']}' sincronizado: id local $localId → id servidor $serverId");
        } else {
          print("❌ Falha ao sincronizar cliente '${cliente['nome']}': ${response.body}");
        }
      } catch (e) {
        print("🚨 Erro ao sincronizar cliente offline: $e");
      }
    }
  }

  // --- ENVIAR VENDAS PARA O SERVIDOR (EM LOTE) ---
  static Future<int> enviarVendasPendentes() async {
    // Passo 1: garante que todos os clientes criados offline já existem no servidor
    await _sincronizarClientesPendentes();

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
          "quantidade": item['quantidade_kg']?.toString() ?? "0.0",
          "preco_unitario": item['preco_unitario']?.toString() ?? "0.0",
          "pecas": item['quantidade_pecas']?.toString() ?? "",
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
        print("🚀 [LOTE] Enviando nota ${venda['numero_nota']} para o Render...");
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
          print("❌ [LOTE] Erro ao enviar nota: ${response.statusCode} - ${response.body}");
        }
      } catch (e) {
        print("🚨 [LOTE] Sem internet ou servidor dormindo: $e");
      }
    }
    return enviadasComSucesso;
  }

  // --- ENVIAR UMA ÚNICA VENDA ---
  static Future<bool> enviarVendaUnica(int vendaId) async {
    // Passo 1: garante que o cliente desta venda já existe no servidor
    await _sincronizarClientesPendentes();

    final db = await DBHelper().database;
    final vendas = await db.query('vendas', where: 'id = ?', whereArgs: [vendaId]);
    if (vendas.isEmpty) return false;
    final venda = vendas.first;

    final itens = await db.query('venda_itens', where: 'venda_id = ?', whereArgs: [vendaId]);

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
      print("🚀 [INDIVIDUAL] Enviando nota ${venda['numero_nota']} para o Render...");
      final response = await http.post(
        Uri.parse('$baseUrl/vendas'),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      print("📦 [INDIVIDUAL] Resposta API: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 201) {
        await db.update('vendas', {'status_sincronizacao': 'sincronizada'}, where: 'id = ?', whereArgs: [vendaId]);
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