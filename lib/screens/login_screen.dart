import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart'; // Criaremos no próximo passo!

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = false;

  void _fazerLoginESincronizar() async {
    setState(() => isLoading = true);

    // Chama o nosso motor de comunicação
    bool sucesso = await ApiService.sincronizarDados();

    setState(() => isLoading = false);

    if (sucesso) {
      // Se deu certo, vai para a Lista de Vendas (Dashboard)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      // Se deu erro (ex: sem internet)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Erro de conexão! Verifique a internet e a URL do Render.",
            style: TextStyle(fontSize: 18),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_shipping, size: 100, color: Colors.amber),
              const SizedBox(height: 24),
              const Text(
                "BOI DELIVERY",
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Sistema de Vendas Mobile",
                style: TextStyle(fontSize: 20, color: Colors.grey),
              ),
              const SizedBox(height: 60),

              isLoading
                  ? const CircularProgressIndicator(color: Colors.amber)
                  : SizedBox(
                      width: 300,
                      height: 80,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(
                          Icons.sync,
                          size: 32,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "SINCRONIZAR E ENTRAR",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: _fazerLoginESincronizar,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
