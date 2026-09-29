// Gera os ícones da aplicação e as imagens para as lojas a partir da marca da KUSSUMBA
// (o mesmo desenho do ícone da versão web) e das telas com os dados das telas de referência.
//
// Uso (na pasta do projecto):  flutter test ferramentas/imagens_lojas_test.dart
//
// Escreve:
//   android/app/src/main/res/mipmap-*/ic_launcher.png   ícone para Android anterior ao 8 (cantos redondos)
//   ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png  ícones do iPhone (quadrados, sem transparência)
//   loja/icone-play-512.png                              ícone da Google Play
//   loja/grafico-destaque-1024x500.png                   imagem de destaque da Google Play
//   loja/capturas/android/*.png (1080 × 1920)            capturas para a Google Play
//   loja/capturas/iphone/*.png (1290 × 2796)             capturas para a App Store (ecrã de 6,9")
// As lojas não aceitam transparência nestas imagens: saem em PNG de 24 bits (RGB).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as pintura;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kussumba/interface/encaminhador.dart';
import 'package:kussumba/interface/tema.dart';
import 'package:kussumba/main.dart';
import 'package:kussumba/nucleo/datas.dart';

import '../test/cenarios.dart';

final _moldura = GlobalKey();

// Traços da marca (os mesmos de lib/interface/icones.dart e da versão web, icones/favicon.svg).
const _tracos = '<g fill="none" stroke="#FFFFFF" stroke-width="26" stroke-linecap="round" stroke-linejoin="round">'
    '<path d="M100 178h312"/><path d="M124 178c6 96 58 160 132 160s126-64 132-160"/>'
    '<path d="M178 238h156"/><path d="M216 288h80"/></g>';

String _marca({required bool cantosRedondos}) => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">'
    '<rect width="512" height="512"${cantosRedondos ? ' rx="112"' : ''} fill="#1E6B52"/>$_tracos</svg>';

/// Só os traços, sem o quadrado verde, para a imagem de destaque.
const _tracosSoltos = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="80 150 352 212">$_tracos</svg>';

// ---------- PNG ----------

final List<int> _tabelaCrc = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
  }
  return c;
});

int _crc(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _tabelaCrc[(c ^ b) & 0xFF] ^ (c >>> 8);
  }
  return c ^ 0xFFFFFFFF;
}

List<int> _bloco(String tipo, List<int> dados) {
  final corpo = [...ascii.encode(tipo), ...dados];
  final tamanho = ByteData(4)..setUint32(0, dados.length);
  final crc = ByteData(4)..setUint32(0, _crc(corpo));
  return [...tamanho.buffer.asUint8List(), ...corpo, ...crc.buffer.asUint8List()];
}

/// PNG de 24 bits (sem canal de transparência) a partir dos pixels RGBA de uma imagem opaca.
Uint8List _pngSemTransparencia(Uint8List rgba, int largura, int altura) {
  final linhas = Uint8List(altura * (1 + largura * 3));
  var j = 0;
  for (var y = 0; y < altura; y++) {
    linhas[j++] = 0; // sem filtro
    for (var x = 0; x < largura; x++) {
      final i = (y * largura + x) * 4;
      linhas[j++] = rgba[i];
      linhas[j++] = rgba[i + 1];
      linhas[j++] = rgba[i + 2];
    }
  }
  final cabecalho = ByteData(13)
    ..setUint32(0, largura)
    ..setUint32(4, altura)
    ..setUint8(8, 8) // 8 bits por canal
    ..setUint8(9, 2); // RGB
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ..._bloco('IHDR', cabecalho.buffer.asUint8List()),
    ..._bloco('IDAT', zlib.encode(linhas)),
    ..._bloco('IEND', const []),
  ]);
}

// ---------- Desenho ----------

Future<void> _desenhar(WidgetTester tester, Widget conteudo, Size tamanho, double densidade) async {
  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = densidade;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(key: _moldura, child: conteudo));
  await assentar(tester);
  expect(tester.takeException(), isNull);
}

/// Grava o que está desenhado. Com transparência só para o ícone de cantos redondos do Android.
Future<void> _gravar(WidgetTester tester, String caminho, double densidade, {bool transparencia = false}) async {
  final moldura = tester.renderObject<RenderRepaintBoundary>(find.byKey(_moldura));
  await tester.runAsync(() async {
    final imagem = await moldura.toImage(pixelRatio: densidade);
    final Uint8List bytes;
    if (transparencia) {
      bytes = (await imagem.toByteData(format: pintura.ImageByteFormat.png))!.buffer.asUint8List();
    } else {
      final rgba = (await imagem.toByteData(format: pintura.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      bytes = _pngSemTransparencia(rgba, imagem.width, imagem.height);
    }
    File(caminho)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  });
}

Widget _icone(String svg, double lado) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: SvgPicture.string(svg, width: lado, height: lado)),
    );

void main() {
  setUpAll(carregarLetra);
  setUp(baseNova);
  tearDown(() => definirRelogio(null));

  testWidgets('ícones do Android (anteriores ao Android 8)', (tester) async {
    const tamanhos = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
    for (final MapEntry(key: densidade, value: lado) in tamanhos.entries) {
      await _desenhar(tester, _icone(_marca(cantosRedondos: true), lado.toDouble()), Size.square(lado.toDouble()), 1);
      await _gravar(tester, 'android/app/src/main/res/mipmap-$densidade/ic_launcher.png', 1, transparencia: true);
    }
  });

  testWidgets('ícones do iPhone e da Google Play', (tester) async {
    final pasta = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final conteudo = jsonDecode(File('$pasta/Contents.json').readAsStringSync()) as Map<String, dynamic>;
    final feitos = <String>{};
    for (final imagem in (conteudo['images'] as List).cast<Map<String, dynamic>>()) {
      final nome = imagem['filename'] as String;
      if (!feitos.add(nome)) continue;
      final lado = double.parse((imagem['size'] as String).split('x').first) * double.parse((imagem['scale'] as String).replaceAll('x', ''));
      await _desenhar(tester, _icone(_marca(cantosRedondos: false), lado), Size.square(lado), 1);
      await _gravar(tester, '$pasta/$nome', 1);
    }
    await _desenhar(tester, _icone(_marca(cantosRedondos: false), 512), const Size.square(512), 1);
    await _gravar(tester, 'loja/icone-play-512.png', 1);
  });

  testWidgets('imagem de destaque da Google Play (1024 × 500)', (tester) async {
    final destaque = Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: Cores.verde,
        padding: const EdgeInsets.symmetric(horizontal: 88),
        child: Row(children: [
          SvgPicture.string(_tracosSoltos, width: 260, height: 157),
          const SizedBox(width: 64),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KUSSUMBA',
                    style: TextStyle(fontFamily: fonte, fontSize: 76, fontWeight: FontWeight.w800, letterSpacing: 5, color: Colors.white)),
                SizedBox(height: 14),
                Text('A tua comadre nas compras de casa.',
                    style: TextStyle(fontFamily: fonte, fontSize: 30, height: 1.3, color: Color(0xFFE1EFE8))),
              ],
            ),
          ),
        ]),
      ),
    );
    await _desenhar(tester, destaque, const Size(1024, 500), 1);
    await _gravar(tester, 'loja/grafico-destaque-1024x500.png', 1);
  });

  // Capturas: mesmas telas nos dois tamanhos que as lojas pedem, com os dados das telas de referência.
  const aparelhos = {'android': Size(1080, 1920), 'iphone': Size(1290, 2796)};
  final telas = <(String, String, Future<void> Function())>[
    ('01_mes', 'mes', setembroComCompras),
    ('02_lista', 'lista', setembroComLista),
    ('03_catalogo', 'catalogo', setembroComLista),
    ('04_comprar', 'comprar', compraNoCazenga),
    ('05_relatorio', 'relatorio', setembroTerminado),
    ('06_novo_mes', 'novo-mes', setembroFechado),
  ];
  for (final MapEntry(key: aparelho, value: tamanho) in aparelhos.entries) {
    for (final (nome, caminho, preparar) in telas) {
      testWidgets('captura $aparelho $nome', (tester) async {
        await tester.runAsync(preparar);
        await _desenhar(tester, KussumbaApp(encaminhador: Encaminhador(caminho)), tamanho, 3);
        if (caminho == 'comprar') {
          // O preço pago da tela 4: 10 000 Kz. As teclas podem estar abaixo do ecrã; depois volta-se ao topo.
          for (final tecla in ['1', '0', '000']) {
            await tester.ensureVisible(find.text(tecla).first);
            await tester.pump();
            await tester.tap(find.text(tecla).first);
            await tester.pump();
          }
          tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
          await assentar(tester);
          expect(find.text('10 000 Kz'), findsOneWidget);
        }
        await _gravar(tester, 'loja/capturas/$aparelho/$nome.png', 3);
      });
    }
  }
}
