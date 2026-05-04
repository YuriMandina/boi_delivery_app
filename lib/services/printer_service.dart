// lib/services/printer_service.dart
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  /// Retorna a lista de impressoras Bluetooth pareadas no dispositivo.
  Future<List<BluetoothDevice>> obterDispositivos() async {
    try {
      return await bluetooth.getBondedDevices();
    } on PlatformException {
      return [];
    }
  }

  /// Conecta à impressora selecionada, garantindo canal limpo.
  Future<bool> conectar(BluetoothDevice device) async {
    try {
      bool? isConnected = await bluetooth.isConnected;
      if (isConnected == true) {
        await bluetooth.disconnect();
      }
      await bluetooth.connect(device);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Desconecta a impressora atual.
  Future<void> desconectar() async {
    try {
      await bluetooth.disconnect();
    } catch (_) {}
  }

  /// Envia o texto formatado para a impressora térmica.
  Future<bool> imprimirTexto(String texto) async {
    try {
      bool? isConnected = await bluetooth.isConnected;
      if (isConnected != true) return false;

      bluetooth.printCustom(texto, 0, 0);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();

      return true;
    } catch (e) {
      return false;
    }
  }
}