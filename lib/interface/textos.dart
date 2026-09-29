// Pequenos textos repetidos em várias telas.

import '../nucleo/formatos.dart';

/// "1 artigo", "7 artigos".
String plural(num n, String singular, String plural) => '${formatarNumero(n)} ${n == 1 ? singular : plural}';

String artigos(num n) => plural(n, 'artigo', 'artigos');
