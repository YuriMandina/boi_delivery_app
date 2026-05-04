// lib/screens/cadastro_cliente_screen.dart
import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class CadastroClienteScreen extends StatefulWidget {
  const CadastroClienteScreen({Key? key}) : super(key: key);

  @override
  State<CadastroClienteScreen> createState() => _CadastroClienteScreenState();
}

class _CadastroClienteScreenState extends State<CadastroClienteScreen> {
  final _nomeCtrl = TextEditingController();
  final _cpfCnpjCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _cpfCnpjCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    _enderecoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvarCliente() async {
    final nome = _nomeCtrl.text.trim();

    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O nome do cliente é obrigatório.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = await DBHelper().database;

      // Checa duplicata por nome (case-insensitive)
      final existente = await db.query(
        'clientes',
        where: 'LOWER(nome) = ?',
        whereArgs: [nome.toLowerCase()],
      );

      if (existente.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Já existe um cliente com o nome "$nome".'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      await db.insert('clientes', {
        'nome': nome,
        'cpf_cnpj': _cpfCnpjCtrl.text.trim(),
        'telefone': _telefoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'endereco': _enderecoCtrl.text.trim(),
        // Marca como pendente para ser sincronizado com o ERP antes da primeira venda
        'status_sincronizacao': 'pendente',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cliente "$nome" cadastrado! Será sincronizado com o ERP na próxima venda.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _sectionLabel(String label, Color color) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: color,
        letterSpacing: 1.2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Novo Cliente'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aviso contextual
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade700),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Cadastro salvo localmente no tablet. '
                      'O cliente será registrado no ERP automaticamente '
                      'quando você sincronizar a primeira venda com ele.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            _sectionLabel('Dados Obrigatórios', primaryColor),
            const SizedBox(height: 12),

            // Nome
            TextField(
              controller: _nomeCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                labelText: 'Nome *',
                hintText: 'Ex: João da Silva',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),

            const SizedBox(height: 32),
            _sectionLabel('Dados Complementares', Colors.grey),
            const SizedBox(height: 4),
            const Text(
              'Todos os campos abaixo são opcionais.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // CPF / CNPJ
            TextField(
              controller: _cpfCnpjCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'CPF / CNPJ',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Telefone
            TextField(
              controller: _telefoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefone / WhatsApp',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // E-mail
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Endereço
            TextField(
              controller: _enderecoCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Endereço',
                prefixIcon: Icon(Icons.location_on_outlined),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 40),

            // Botão de salvar
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _salvarCliente,
                icon: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSaving ? 'SALVANDO...' : 'SALVAR CLIENTE',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}