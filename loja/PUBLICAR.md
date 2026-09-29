# Publicar a KUSSUMBA nas lojas

Este guia diz o que já está pronto e o que falta fazer para a KUSSUMBA aparecer na Google Play e na App Store. As contas nas lojas são pessoais e pagas, por isso só a dona ou o dono do projecto as pode criar.

## O que já está pronto

| O quê | Onde |
| --- | --- |
| Pacote para a Google Play (AAB assinado) | `build/app/outputs/bundle/release/app-release.aab` |
| APK assinado, para instalar à mão | `build/app/outputs/flutter-apk/app-release.apk` |
| Chave de envio para a Google Play | `C:\Users\csmju\develop\chaves\kussumba-envio.jks` |
| Palavra-passe da chave | `android\key.properties` (fica só neste computador, o git ignora-o) |
| Ícones do Android e do iPhone | dentro da aplicação |
| Textos, imagens e respostas das fichas | `loja/textos.md` e as imagens em `loja/` |
| Política de privacidade | `loja/privacidade.md` (falta um endereço público) |

**Guarda uma cópia da chave e da palavra-passe fora deste computador** (numa pen e num cofre de palavras-passe, por exemplo). Todas as versões futuras têm de ser enviadas com esta chave. Se se perder, a Google pode trocá-la a pedido, mas o processo demora.

## Antes das lojas: experimentar no teu telemóvel Android

1. Copia `app-release.apk` para o telemóvel (por cabo, email ou Google Drive).
2. Abre o ficheiro no telemóvel e aceita instalar aplicações desta origem.
3. Experimenta sobretudo o que só um telemóvel verdadeiro mostra:
   - guardar uma cópia de segurança e escolher onde fica;
   - repor essa cópia (nas boas-vindas, noutro telemóvel, ou em Mês › Cópia de segurança);
   - aumentar a letra nas definições do telefone e ver as telas;
   - o ícone no ecrã inicial e nos ícones temáticos do Android 13.

## Google Play

1. **Conta de programador** em <https://play.google.com/console>: conta pessoal, pagamento único de 25 dólares e verificação de identidade com um documento.
2. **Criar a aplicação:** nome "KUSSUMBA: compras de casa", idioma português (Portugal), aplicação gratuita.
3. **Ficha da loja:** textos e imagens de `loja/textos.md`.
4. **Conteúdo da aplicação:** endereço da política de privacidade, segurança dos dados, questionário de classificação, público-alvo (18 anos ou mais) e publicidade (não tem). As respostas estão em `loja/textos.md`.
5. **Teste fechado:** as contas pessoais novas têm de fazer um teste fechado com pelo menos 12 pessoas durante 14 dias seguidos antes de poderem publicar para toda a gente. Cada pessoa precisa de uma conta Google e de aceitar o convite. Envia o AAB para esse teste.
6. **Produção:** passados os 14 dias, pede o acesso à produção na consola e publica.

## App Store

1. **Programa de programadores da Apple** em <https://developer.apple.com/programs/>: 99 dólares por ano, inscrição individual com um Apple ID com verificação em dois passos.
2. **App Store Connect:** criar a aplicação com o identificador `io.github.kussumba.app`.
3. **Assinatura e envio:** sem Mac, a versão assinada compila-se no GitHub, num computador Mac da compilação automática, com o certificado de distribuição e o perfil guardados como segredos do repositório. Este passo prepara-se quando a conta existir.
4. **Ficha:** textos e capturas de `loja/`, privacidade "Não são recolhidos dados", classificação 4+.
5. **Revisão:** a Apple revê cada versão antes de a publicar.

## Política de privacidade: onde a publicar

As duas lojas pedem um endereço público para a política de privacidade. A proposta é publicá-la no site da KUSSUMBA, em `https://kussumba.github.io/privacidade.html`, com o texto de `loja/privacidade.md`.

## Versões seguintes

Em cada versão nova, aumenta-se o número em `pubspec.yaml` (por exemplo, `1.0.1+2`: o número depois do `+` tem de subir sempre) e compila-se outra vez com `flutter build appbundle --release`.
