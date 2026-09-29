# Textos para as lojas

Textos da ficha da KUSSUMBA na Google Play e na App Store, dentro dos limites de caracteres de cada loja.

## Google Play

**Nome da aplicação** (até 30 caracteres)

KUSSUMBA: compras de casa

**Descrição breve** (até 80 caracteres)

Lista do mês, preços pagos e sobra do plafond, em Kz e sem internet.

**Descrição completa** (até 4000 caracteres)

A KUSSUMBA é a tua comadre nas compras de casa. Ajuda a planear o mês, a comprar com a lista na mão e a perceber para onde foi o dinheiro.

Como funciona:

• Começas por indicar o plafond do mês para as compras de casa.
• Fazes a lista a partir do catálogo: arroz, óleo, açúcar, feijão, fuba, leite, sabão e muito mais. Podes criar os teus próprios produtos.
• Em cada ida às compras, registas o preço que pagaste, artigo a artigo, com um teclado grande e simples.
• A KUSSUMBA mostra logo quanto sobra no mês, se o preço subiu desde a última compra e se a lista cabe no saldo.
• No fim do mês, vês o relatório: quanto gastaste, o que subiu e o que desceu de preço, e em que lojas gastaste mais.
• Ao começar o mês seguinte, copias a lista com os últimos preços pagos e recebes uma sugestão de plafond conforme a subida dos preços.

Feita para Angola:

• Valores em kwanzas, com os números escritos como os lemos.
• Produtos do dia-a-dia, das mercearias aos frescos, limpeza, higiene e bebidas.
• Funciona sem internet. Os dados ficam só no teu telefone.

Privada por natureza:

• Não pede conta, nome, número de telefone nem email.
• Não tem publicidade nem envia dados para ninguém.
• Para mudar de telefone, guardas uma cópia de segurança num ficheiro e repões no telefone novo.

Letra grande: a KUSSUMBA acompanha o tamanho de letra que escolheres nas definições do telefone.

**Categoria:** Finanças

**Etiquetas sugeridas:** orçamento, lista de compras, poupança

## App Store

**Nome** (até 30 caracteres)

KUSSUMBA: compras de casa

**Subtítulo** (até 30 caracteres)

A tua comadre nas compras

**Texto promocional** (até 170 caracteres)

Planeia a lista do mês, regista o que pagas e vê quanto sobra do plafond. Em kwanzas, sem internet e sem contas.

**Descrição** (até 4000 caracteres)

Usar a mesma descrição completa da Google Play.

**Palavras-chave** (até 100 caracteres, separadas por vírgulas)

compras,lista,orçamento,plafond,kwanza,Angola,mercado,preços,poupança,despesas,casa

**Categoria principal:** Finanças. **Categoria secundária:** Compras.

## Respostas comuns às duas lojas

**Idade:** conteúdo para todas as idades (sem violência, jogos, compras dentro da aplicação nem conteúdo gerado por outras pessoas). Público-alvo: adultos que fazem as compras de casa (18 anos ou mais), para a aplicação não ficar sujeita às regras das aplicações para crianças.

**Segurança dos dados (Google Play) e privacidade (App Store):**

- A aplicação não recolhe dados: nada sai do telefone.
- A aplicação não partilha dados com terceiros.
- Não há contas, publicidade, estatísticas de uso nem ligação à internet. A versão final nem sequer tem permissão para usar a internet.
- A cópia de segurança é um ficheiro que a própria pessoa decide guardar, no sítio que escolher.
- Na App Store, a resposta é "Não são recolhidos dados" (Data Not Collected).

**Política de privacidade:** o texto está em `privacidade.md` e precisa de um endereço público (ver `PUBLICAR.md`).

**Contacto de apoio:** página de pedidos do projecto, <https://github.com/kussumba/kussumba-app/issues>.

## Imagens

| Ficheiro | Para quê |
| --- | --- |
| `icone-play-512.png` | Ícone da Google Play (512 × 512) |
| `grafico-destaque-1024x500.png` | Imagem de destaque da Google Play |
| `capturas/android/*.png` | Capturas para a Google Play (1080 × 1920) |
| `capturas/iphone/*.png` | Capturas para a App Store, ecrã de 6,9" (1290 × 2796) |

O ícone da App Store (1024 × 1024) já vai dentro da aplicação. Para voltar a gerar as imagens: `flutter test ferramentas/imagens_lojas_test.dart`.
