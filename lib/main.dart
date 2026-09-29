// Arranque da KUSSUMBA nativa.
// Ecrã provisório: as telas chegam no passo 6 do plano. Por agora, abre a base de dados
// e mostra quantos produtos tem o catálogo, para provar que a camada de dados funciona no telemóvel.

import 'package:flutter/material.dart';

import 'servicos/produtos.dart';

void main() {
  runApp(const KussumbaApp());
}

class KussumbaApp extends StatelessWidget {
  const KussumbaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KUSSUMBA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E6B52)),
        scaffoldBackgroundColor: const Color(0xFFF6F3EE),
      ),
      home: const _Provisorio(),
    );
  }
}

class _Provisorio extends StatelessWidget {
  const _Provisorio();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KUSSUMBA', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('A tua comadre nas compras de casa.'),
              const SizedBox(height: 24),
              FutureBuilder(
                future: listarProdutos(),
                builder: (context, estado) {
                  if (estado.hasError) return Text('Erro ao abrir os dados: ${estado.error}');
                  if (!estado.hasData) return const Text('A abrir os dados…');
                  return Text('Catálogo com ${estado.data!.length} produtos. As telas chegam no próximo passo.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
