# KUSSUMBA (aplicação nativa)

*A tua comadre nas compras de casa.*

Aplicação nativa da KUSSUMBA para Android e iPhone, feita em Flutter. Segue o mesmo desenho, as mesmas regras de cálculo e o mesmo formato de cópia de segurança da versão web (<https://kussumba.github.io/>).

## Organização

| Pasta | Conteúdo |
| --- | --- |
| `lib/nucleo` | Cálculos (§43 do prompt mestre), formatos em Kz, unidades, datas, alertas e estados. |
| `lib/dados` | Base de dados local SQLite, migrações, modelos e catálogo inicial. |
| `lib/servicos` | Regras de negócio: meses, lista, catálogo, compras, histórico de preços, relatório e cópia de segurança. |
| `test` | Testes com os números do prompt mestre, iguais aos da versão web. |
| `fontes` | DM Sans (licença OFL). |

## Testes

```powershell
flutter test
```

Os testes correm no computador, com SQLite em memória; não precisam de telemóvel.

A cada envio para o GitHub, a compilação automática corre os testes e compila para Android e para iPhone.
