# Licenças de conteúdo

Registro de todo conteúdo (código, regras, arte, áudio, fontes) que não foi criado do zero para o projeto.
Conteúdo com licença não verificada **não** entra na versão distribuída.

Campos: nome · fonte · autor/titular · licença · URL · data de obtenção · modificações · obrigações.

| Conteúdo | Fonte / Autor | Licença | URL | Obtido em | Modificações | Obrigações |
|---|---|---|---|---|---|---|
| Godot Engine 4.7.2 (runtime no build Web) | Godot Engine contributors | MIT | https://github.com/godotengine/godot | 2026-10-23 | Nenhuma | Manter aviso MIT e avisos de `COPYRIGHT.txt` (ver `THIRD_PARTY_NOTICES.md`) |
| Regras e conteúdo do SRD 5.2.1 (`scripts/rules/`, `data/`) | Wizards of the Coast LLC | CC BY 4.0 | https://www.dndbeyond.com/srd | 2026-10-23 | Mecânicas reimplementadas em código; nomes traduzidos; descrições resumidas com texto próprio; kit inicial simplificado (ver `RULES_POLICY.md`) | Texto de atribuição oficial no jogo (Créditos) e em `THIRD_PARTY_NOTICES.md`; indicar modificações |

## Conteúdo próprio

Assets originais do projeto estão em `assets/asset_catalog.json` com `source_type` e `license: project`.
A licença do conteúdo próprio ainda não foi escolhida (decisão pendente do responsável).

## Referências (fora do build)

| Conteúdo | Origem | Uso |
|---|---|---|
| `docs/art_reference/species_reference.webp` | Gerada com IA pelo responsável do projeto (2026-10-24) | Só referência de opções de aparência; não é importada nem exportada (`.gdignore`); nenhum pixel copiado para os sprites |

## SRD 5.2.1

Em uso desde a Fase 2. Lista do que foi usado e das adaptações em [RULES_POLICY.md](RULES_POLICY.md).
Todo registro em `data/` tem o campo `source` (`"SRD 5.2.1"` ou `"original"`).
