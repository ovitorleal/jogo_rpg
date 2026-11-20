---
feature: livros-de-arghaz
fase: security
data: 2026-11-20
projeto: As Crônicas de Arghaz
referencia_spec: tasks/specs/livros-de-arghaz.md
nivel_risco_geral: Baixo
aprovado: false
llm-routing:
  proxima-fase: passo-4-code
  modelo-padrao-subfase: claude-haiku-5-5
  modelo-elevado-subfase: claude-sonnet-5-5
  thinking: false
  effort: baixo
  subfases-que-elevam-modelo: [F4, F5]
  justificativa: "3 contramedidas simples, sem auth, dinheiro ou PII; F4 (posição salva) e F5 (regerar mapas) mexem em código e cenas que quem já joga sente."
---

# Threat Model — Livros de Arghaz

## Sumário Executivo

A onda troca texto do jogo, reescreve documentos, cria peças de cenário geradas por script, regera três mapas e
ajusta a posição restaurada do save. O jogo não tem servidor, conta, rede nem dado pessoal. Risco geral **baixo**.

O achado relevante desta fase não é de código: **o repositório é público no GitHub, e os livros inéditos do mestre
estão nele desde o PR #29** (`docs/livros/`). O responsável decidiu **manter público** (2026-11-20). Fica registrado
como risco aceito (RR-LA-01). O jogo exportado para a Web **não** leva os livros (verificado no filtro de exportação).

## Inventário de Componentes

| # | Componente | O que faz | Fase do spec |
|---|---|---|---|
| C1 | Dados de texto (`data/lore`, `data/story`, `data/quests`, `data/dialogues`, `data/companions`, `data/regions`, `data/routes`) e strings em código | Texto exibido ao jogador | F1 |
| C2 | `docs/livros/` (3 `.docx` do mestre + transcrições) e documentos do cânone | Fonte da verdade da história | F2 (e já no `main`) |
| C3 | Gerador de arte (`tools/art/generate_environment.gd`) e atlas | Peças do Ermo em PNG | F3 |
| C4 | Restauração da posição salva (`exploration_map.gd`, ramo `if back is Vector2:`) | Tira o jogador de dentro de colisão | F4 |
| C5 | Gerador de mapas (`tools/art/build_overworld.gd`) e cenas regeradas | Ermo nos mapas | F5 |

## Dados Processados

| Dado | Origem | Sensível? | Onde fica |
|---|---|---|---|
| Texto da história | Livros do mestre + escrita da onda | Não (mas é propriedade intelectual do mestre) | Repositório público e jogo exportado |
| Livros do mestre (`.docx` e `.md`) | Arquivos enviados pelo responsável | **Inédito do mestre** | Repositório público (RR-LA-01); fora do jogo exportado |
| Posição do jogador no save | Arquivo `user://` do jogador | Não | Máquina ou navegador do jogador |

Nenhum dado pessoal, credencial, segredo ou pagamento.

## Trust Boundaries

| Fronteira | O que entra | Quem está do outro lado | Validação |
|---|---|---|---|
| TB1: arquivo de save → jogo | `player_position` (array de 2 números) | O próprio jogador, que pode editar o arquivo | Hoje só o formato é conferido (`save_game.gd:122-124`). **CM-LA-01** acrescenta valor finito, dentro do mapa e livre de colisão |
| TB2: `.docx` externo → repositório | Arquivos do mestre, enviados pelo responsável | Autor externo | Inspecionados em 2026-11-20: sem macros (`vbaProject`), objetos embutidos (`oleObject`, `embeddings/`) ou links externos. Nunca abertos nem executados pelo pipeline; a transcrição usa só leitura de XML |
| TB3: repositório → jogo exportado | Tudo o que o filtro de exportação deixa passar | Público da Web | `export_filter="all_resources"`, `include_filter="data/*.json"`, `exclude_filter="tests/*,tools/*,exports/*"`: `.docx` e `.md` não entram. **CM-LA-03** confere isso ao final |

## STRIDE por Componente

### C1: Dados de texto
- **S / R / E:** não se aplica (sem identidade nem permissões).
- **T:** os JSON são do próprio repositório; quem altera é quem tem acesso de escrita (protegido por PR e CI).
- **I:** nada sensível.
- **D:** texto maior não afeta desempenho de forma relevante.
- Risco de integridade real: trocar um **id** quebraria saves. Contramedida já no spec (ids não mudam) e verificada no
  passo 5 (`git diff` sem linha `"id":` alterada).

### C2: Livros do mestre
- **I (Information disclosure):** o repositório é público, e o material inédito pode ser lido por qualquer pessoa.
  **Risco aceito pelo responsável** (RR-LA-01).
- **T:** os `.docx` foram inspecionados (TB2); as transcrições `.md` são texto puro.

### C3: Gerador de arte
- **T / D:** roda só na máquina de quem desenvolve; não processa entrada externa. Risco: regenerar e alterar asset
  existente sem querer. Contramedida no spec (rodar sem mudança e conferir o `git status`).

### C4: Posição salva
- **T (Tampering):** o jogador pode editar o save e pôr qualquer posição. Hoje isso é aceito cru. Com a busca nova,
  uma posição absurda (gigante, NaN, infinita) não pode travar nem estourar a busca. **CM-LA-01.**
- **D (Denial of service):** a busca de casa livre precisa ter limite fixo. **CM-LA-01.**

### C5: Mapas regerados
- **T / D:** sem entrada externa. Risco de integridade: o `--force` apagar edições do editor e a sequência aleatória
  mover objetos. Contramedidas no spec (teste de reprodução, RNG separado, teste de preservação).

## OWASP Top 10 (2021 / 2025-RC1) — Checklist

### A01: Broken Access Control
Não se aplica: não há usuários, papéis nem servidor. O acesso de escrita ao repositório é controlado pelo GitHub
(proteção do `main`, Onda Zero).

### A02: Cryptographic Failures
Não se aplica: nada é cifrado nem precisa ser.

### A03: Injection (2025: Software Supply Chain Failures é A03)
- Injeção: os textos vão para `Label` e `RichTextLabel`. O conteúdo é do repositório, não do jogador. **CM-LA-02:** o
  texto novo não pode conter colchetes de BBCode por acidente (`[...]`) onde o componente interpreta BBCode.
- Cadeia de suprimentos: **nenhuma dependência nova**. Os `.docx` são dados, não código, e não entram no build.

### A04: Insecure Design
O desenho seguro está no spec: ids imutáveis, fallback para `Entrances/*` na posição salva e mapas regerados com
teste de preservação.

### A05: Security Misconfiguration
Filtro de exportação conferido (TB3). `tasks/.gdignore` já impede o Godot de importar o que está em `tasks/`.
**CM-LA-03:** conferir no fim que o pacote Web não contém `docs/`.

### A06: Vulnerable and Outdated Components
Sem componentes novos. Godot 4.7.2, igual ao CI.

### A07: Identification and Authentication Failures
Não se aplica.

### A08: Software and Data Integrity Failures
- Save: CM-LA-01 (posição) e ids imutáveis (spec).
- Assets: o gerador não pode alterar assets existentes (spec, F3).
- CI: testes e gitleaks em todo push (Onda Zero).

### A09: Security Logging and Monitoring Failures
Não há servidor. A correção de posição registra no log do Godot (`print`, não `push_error`) quando desloca o jogador,
para depuração. Não há dado pessoal no log.

### A10: Server-Side Request Forgery (SSRF; em 2025 dentro de A01)
Não se aplica: o jogo não faz requisições.

**OWASP API (2023):** não se aplica (sem endpoint). **OWASP LLM (2025)** e **Agentic (2026):** não se aplicam (o jogo
não usa IA; a reescrita do texto é trabalho de desenvolvimento, revisado frase a frase contra as fontes).

## Secrets Necessários

Nenhum.

## Headers de Segurança Específicos

Nenhum além do que já existe. O jogo não tem servidor próprio; a CSP é o risco residual RR-OZ-01 da Onda Zero.

## Rate Limiting

Não se aplica (sem endpoint).

## Logging para Auditoria

Só o registro de depuração da CM-LA-01. Nada sensível.

## Contramedidas

| ID | Contramedida | Onde | Prova no passo 5 |
|---|---|---|---|
| **CM-LA-01** | Na restauração da posição salva, aceitar só valores finitos. Uma posição fora do mapa vai para o primeiro `Entrances/*`. A busca de casa livre tem raio máximo fixo (anéis de 16 px, no máximo 8) e depois cai na entrada. Posição livre e dentro do mapa: comportamento idêntico ao de hoje | `exploration_map.gd` (ramo `if back is Vector2:`) | Testes com posição sobre árvore, livre, fora do mapa, NaN e infinita |
| **CM-LA-02** | Texto novo sem `[`/`]` literais em campos exibidos por `RichTextLabel` com BBCode, salvo tags de propósito | `data/*.json`, strings da F1 | Grep no diff dos textos novos |
| **CM-LA-03** | O pacote Web não contém `docs/` nem `.docx` | `export_presets.cfg` (sem mudança) | Exportar e listar o conteúdo do `.pck` |

## Plano de Teste de Segurança (para o passo-5)

1. CM-LA-01: os cinco casos de posição acima, mais um save antigo do meio do Ato I carregando sem deslocar quem está
   livre.
2. CM-LA-02: grep por `\[` nos valores de texto alterados.
3. CM-LA-03: exportar para a Web e conferir que nenhum caminho `res://docs/` aparece no pacote.
4. Ids: `git diff main...onda/livros-de-arghaz` sem nenhuma linha `"id":` alterada.

## Riscos Residuais (Aceitos)

| ID | Risco | Decisão |
|---|---|---|
| **RR-LA-01** | Os livros inéditos do mestre (Livro I, Livro II e o compêndio rascunho) estão públicos no GitHub desde o PR #29, inclusive no histórico | **Aceito pelo responsável** (Vitor Leal, 2026-11-20: "Manter público"). Se o mestre pedir sigilo depois, as saídas são tornar o repositório privado ou remover os arquivos e reescrever o histórico (exige liberar a proteção do `main` e novo clone de quem colabora) |
| RR-OZ-01 | Sem CSP no site (herdado da Onda Zero) | Já aceito na Onda Zero |

## Status

- [x] STRIDE aplicado a cada componente
- [x] OWASP Web percorrido item por item; API, LLM e Agentic avaliados como não aplicáveis
- [x] Trust boundaries com validação definida
- [x] Secrets: nenhum
- [x] Contramedida concreta para cada risco
- [x] Plano de teste de segurança para o passo 5
- [ ] Aprovado pelo responsável

aprovado: false
