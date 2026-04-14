import 'package:flutter/material.dart';
// Importa a nossa tela de vendas
import 'screens/venda_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const BoiDeliveryApp());
}

class BoiDeliveryApp extends StatelessWidget {
  const BoiDeliveryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boi Delivery',
      debugShowCheckedModeBanner:
          false, // Tira aquela faixa de "DEBUG" do canto
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Define a fonte padrão (opcional, mas deixa bonito)
        fontFamily: 'Roboto',
      ),
      // Aqui nós dizemos para o Flutter: "A primeira tela é a VendaScreen!"
      home: const LoginScreen(),
    );
  }
}
