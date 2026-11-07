---
projeto: As Crônicas de Arghaz
stack: Godot 4.7.2 + GDScript tipado, exportado para Web (Compatibility/WebGL 2), site estático no GitHub Pages
data_inicio: 2026-11-07
data_conclusao:
concluido: false
---

# Onda Zero — Fundação do Projeto As Crônicas de Arghaz

> Este arquivo é a evidência da fundação, **adaptada a um jogo Godot sem servidor** (decisão do responsável em
> 2026-11-07). O projeto já existia (versão 0.12.0) quando a metodologia foi adotada. Por isso, vários itens já
> estão prontos e só têm a evidência registrada aqui. Os itens pensados para sistemas web com servidor (banco,
> RLS, autenticação, headers HTTP, validação de variáveis de ambiente) são marcados como **não se aplica** (N/A),
> com o motivo ao lado.
>
> Quando todos os itens estiverem verificados, **o responsável** muda `concluido: false` para `concluido: true`.

## Stack Decidida

- **Linguagem:** GDScript com tipagem estática
- **Engine:** Godot 4.7.2 (renderizador Compatibility / WebGL 2)
- **Banco:** nenhum. O salvamento fica no navegador do jogador (`user://`, IndexedDB), validado ao carregar.
- **Auth:** nenhuma. O jogo é para um jogador, sem contas.
- **Deploy:** exportação Web estática publicada no GitHub Pages (branch `gh-pages`), via `tools/publish/publish_web.sh`.
- **CI:** GitHub Actions (`.github/workflows/ci.yml`).

## 0. Contexto do Projeto (o gate mais básico)

- [x] `CLAUDE.md` com escopo, stack, comandos (testes, importação, exportação, servir o build), convenções e
      regras da casa. Já existia; ganhou a seção da metodologia (esta onda).
- [x] `MEMORY.md` inicializado no diretório de memória do projeto. Já existe com 4 entradas, incluindo a da
      metodologia.
- [x] Escopo/PRD mínimo: `tasks/PRD.md` (o quê, por quê, para quem, regras que não mudam). O detalhe está na
      especificação mestra (`PROJECT_MASTER_SPECIFICATION_FANTASY_RPG_v1.1.md`).

## 1. Bootstrap (adaptado)

- [x] Engine instalada: Godot 4.7.2 (`C:\Users\ovito\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`)
- [x] Tipagem estrita: GDScript tipado como convenção obrigatória (`CLAUDE.md`). Equivale ao "TypeScript strict".
- [x] Estrutura de pastas: `scripts/` (por domínio), `data/` (conteúdo em JSON), `scenes/`, `assets/`, `tests/`,
      `tools/`, `docs/` e `tasks/` (metodologia)
- [ ] Linter + formatter: **ainda não existe** (por exemplo, `gdtoolkit` com gdlint e gdformat). Registrado
      como dívida **D-OZ-01**.
- [ ] Hook de pre-commit: não existe. O CI cobre o essencial; entra junto com a D-OZ-01.
- [x] `.editorconfig`: N/A por enquanto. O padrão do Godot (tabs) é seguido pelo editor e pelas ferramentas.

**Evidência:** projeto em `project.godot`; 295 testes em `tests/`.

## 2. Gestão de Secrets (adaptado)

- [x] **O jogo não usa nenhuma credencial.** Não há chave de API, token nem serviço externo. Busca no código
      sem nenhum segredo (só "token" no sentido de peça de combate).
- [x] `.env.example` e validação Zod: **N/A**. O jogo não lê variáveis de ambiente.
- [x] Prefixos públicos (`NEXT_PUBLIC_*`): **N/A**. Não é Next.js; tudo no pacote Web é público por natureza
      e não contém segredo.
- [x] Detecção de segredos commitados: `gitleaks` no CI varre o histórico inteiro em todo push e PR (item 6).

## 3. Banco com RLS — N/A

O jogo não tem banco nem servidor. O que faz o papel de "dados" é o **salvamento local**, e a proteção
equivalente já existe: `SaveGame.validate` valida tudo ao carregar (checksum, esquema, personagens pelo
`CharacterFactory.validate`, migração de versões antigas), e um arquivo adulterado é rejeitado (testes em
`tests/save/`).

## 4. Auth + Middleware — N/A

Jogo para um jogador, sem contas, sem área administrativa e sem rotas no servidor.

## 5. Headers de Segurança — N/A (com risco residual)

O GitHub Pages não permite configurar headers HTTP. O site é estático, não tem formulário, login, cookies nem
dados de terceiros.
- **RR-OZ-01 (risco residual aceito):** sem CSP. O impacto é baixo, porque não há dados sensíveis nem conteúdo
  de usuário renderizado como HTML. Pode ser revisto se o jogo ganhar conteúdo externo ou contas.

## 6. CI/CD com Gates de Segurança

- [x] `.github/workflows/ci.yml` rodando em todo push e PR
- [x] Testes: o Godot 4.7.2 (Linux, headless) importa o projeto e roda a suíte (`tests/run_tests.gd`), e o job
      falha se algum teste falhar
- [x] Gitleaks 8.30.1 integrado: varre o histórico inteiro e falha se achar segredo
- [x] Autoteste do gitleaks: o CI planta uma chave falsa num diretório temporário (fora do repositório) e exige
      que ele a detecte. Prova a detecção sem commitar segredo.
- [x] Auditoria de dependências (`npm audit`): **N/A**. O jogo não tem dependências de pacote; o Godot é a
      única, fixada na versão 4.7.2.
- [ ] Branch protection na `main` exigindo o CI verde: **pendente**. É configuração da conta no GitHub e
      precisa de aprovação do responsável.
- [x] Deploy separado: `tools/publish/publish_web.sh` (testes, exportação, verificação e publicação no `gh-pages`).

**Evidência:** primeiro run verde, https://github.com/ovitorleal/jogo_rpg/actions/runs/42402936045 (2026-11-07):
**295 testes passaram, 0 falharam** no Linux; gitleaks e o autoteste do segredo plantado passaram.

## 7. Observabilidade Mínima (adaptado)

- [x] Erros de script em tempo de execução são capturados pelo executor de testes (`ScriptErrorCatcher`, um
      `Logger` do Godot) e **reprovam** o teste. Erros de conteúdo aparecem no início com o prefixo `[Content]`.
- [x] Health check: **N/A** (não há servidor). O equivalente é o jogo abrir sem erros e carregar o conteúdo,
      verificado pelos testes de integração (`tests/integration/`).
- [ ] Monitoramento de erros dos jogadores (por exemplo, Sentry): fora do escopo agora. Registrado como
      **D-OZ-02**, para revisitar quando houver jogadores externos.

## Verificação Final

- [x] CI verde no último push deste branch (run 42402936045)
- [x] Gitleaks pegou o segredo plantado (autoteste do CI, mesmo run)
- [x] CSP visível: N/A (RR-OZ-01)
- [x] Rota admin retorna 401: N/A (sem servidor nem contas)
- [x] Health check: N/A (testes de integração no lugar)

## Dívidas e riscos registrados

| ID | Descrição |
|---|---|
| D-OZ-01 | Linter e formatter de GDScript (`gdtoolkit`) e hook de pre-commit |
| D-OZ-02 | Monitoramento de erros dos jogadores |
| RR-OZ-01 | Sem CSP (o GitHub Pages não permite headers) |

## Status

- [ ] Todas as fundações concluídas ou justificadas (N/A ou dívida registrada)
- [ ] Verificação final passou
- [ ] Branch protection decidida pelo responsável
- [ ] Pronto para `/passo-1-research` da primeira onda

**Quando todos os checkboxes estiverem `[x]`, o responsável muda `concluido: false` para `concluido: true` no topo.**

concluido: false
