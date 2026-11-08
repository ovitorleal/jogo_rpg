---
onda: ataque-furtivo-opcional
branch: fix/ataque-furtivo
aberta_em: 2026-11-07
passo_atual: 4
estado: ativa
migration_reservada: 'nenhuma' # sem banco; o salvamento não muda (a escolha vive só durante o combate)
---

Pedido do responsável: perguntar ao jogador, **depois de acertar**, se quer usar o Ataque Furtivo (regra do SRD
5.2.1: o dano extra é opcional, "você pode"). Correção curta fora das ondas do ROADMAP.

## Arquivos e rotas que esta onda toca
- `scripts/combat/combat_manager.gd` — o ataque com arma passa a ter duas metades (rolagem / dano), uma escolha
  pendente (`pending_choice`) e o comando novo `choose`; só os ataques que o jogador dispara (`attack`, `offhand`)
  podem pausar, e só com `interactive_choices = true` (a tela de combate liga; testes e IA não)
- `scripts/combat/combat_features.gd` — `sneak_attack_eligible()` (checagem sem consumir) e respeito à escolha
- `scripts/combat/combat_scene.gd` — pop-up "Acertou! Usar Ataque Furtivo?" (painel criado no código, mesmo estilo
  do painel de resultado)
- `scripts/combat/combat_log.gd` — linha da escolha e "Ataque Furtivo +N" no dano
- `tests/combat/test_martial_features.gd`, `tests/combat/test_sneak_attack_choice.gd` (novo)
- `docs/RULES_POLICY.md`, `docs/CHANGELOG.md`, `docs/ROADMAP.md`

⚠️ `combat_manager.gd` e `combat_scene.gd` também estão na folha de `testes-contra-a-morte` (passo 1, ainda sem
código; o disco dela não tem diff contra o `main`). Esta correção entra antes; aquela onda parte do `main` novo.

## Impacto (engenharia reversa)
- Consumidores de `_resolve_weapon_attack` (grep): `_do_attack`, `_do_offhand`, ataque de oportunidade (manager:456),
  Trespassar (manager:659), contra-ataque e golpes desarmados automáticos (features:789, 1945, 1959, 2248).
  **Só `_do_attack` e `_do_offhand` podem pausar**; todos os outros continuam resolvendo de uma vez e usando o
  Ataque Furtivo automaticamente, como hoje.
- `_resolve_weapon_attack` mantém a assinatura e o comportamento: vira "rolar + terminar" sem pausa.
- Com `interactive_choices = false` (padrão), nada muda: testes atuais e IA idênticos.
- Três populações: novo jogador vê o pop-up ao acertar com o ladino; quem tem save não sente nada (a escolha não é
  salva e o combate não permite salvar); borda: escolha pendente bloqueia qualquer outro comando até responder.

## Backend — o que esta onda CRIA
- nenhum (sem backend)

## 🔴 Backend — o que esta onda ALTERA ou APAGA
- nenhuma (sem backend). Fora de backend, **altera o fluxo do ataque no motor de combate** (duas metades).

## Arquivos de controle desta onda
Esta folha (correção curta, sem research/spec próprios).
