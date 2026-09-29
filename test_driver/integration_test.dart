// Condutor dos testes no telemóvel: guarda as capturas de ecrã em build/capturas_dispositivo.

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
      onScreenshot: (nome, imagem, [argumentos]) async {
        final ficheiro = File('build/capturas_dispositivo/$nome.png');
        await ficheiro.create(recursive: true);
        await ficheiro.writeAsBytes(imagem);
        return true;
      },
    );
