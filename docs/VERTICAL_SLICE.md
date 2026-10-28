# Fatia vertical — "A Garra-Rubra" (Fase 7)

Aventura curta e completa que mostra todos os sistemas do jogo funcionando juntos. Começa em **Novo jogo** e termina
na tela **"Ribeira está salva!"**. O objetivo atual fica sempre no canto superior esquerdo da tela de exploração.

## Roteiro

1. **Vila de Ribeira** (início). A abertura diz para procurar Ione, a chefe da vila, perto do poço.
   Ione oferece a missão principal "A Garra-Rubra" e entrega 2 Poções de Cura. Na estalagem (placa ao norte da praça)
   o grupo faz um descanso longo de graça.
2. **Estrada da Vila** (placa a leste). Viagem de 2 trechos pelos Campos de Ribeira. No primeiro trecho aparece sempre
   a **criança perdida** (encontro não combativo com teste de perícia); depois, o sorteio da região.
3. **Clareira da Encruzilhada**. Amara indica o acampamento de Garra-Rubra e sugere treinar antes contra o goblin da
   ruína (missão opcional "Ameaça na Ruína", com poções de recompensa).
4. **Estrada do Leste** até o **Bosque do Riacho**. Garra-Rubra espera no acampamento, ao lado da fogueira.
5. **Combate** contra Garra-Rubra (chefe goblin do SRD: CA 17, 21 PV, dois ataques por turno).
6. **Volta** pela Estrada do Leste e pela Estrada da Vila até Ione.
7. **Recompensa** (300 XP, 50 PO, 2 poções) e **tela de conclusão** com o resumo. O jogo é salvo antes.
   Dela dá para continuar explorando ou voltar ao título.

## Itens da especificação (seção 40)

| Item | Onde está |
|---|---|
| Uma vila | Vila de Ribeira (`scenes/world/village.tscn`, layout `village` do `build_overworld.gd`) |
| Uma região de exploração | Floresta Sussurrante (Clareira e Bosque do Riacho) e Campos de Ribeira |
| Uma rota de viagem | Estrada da Vila e Estrada do Leste (`data/routes/routes.json`) |
| Um encontro não combativo | Criança perdida, garantida no 1º trecho da Estrada da Vila (`scripted_events`) |
| Um combate | Garra-Rubra (`encounter.goblin_chief`), mais os combates opcionais e sorteados |
| Uma missão | "A Garra-Rubra" (`data/quests/main_quest.json`, `final: true`) |
| Um NPC | Ione (`data/dialogues/ione.json`), além de Amara |
| Uma recompensa | XP, ouro e poções da missão, ouro e poção do encontro |
| Um salvamento | Autosave nos pontos seguros e salvamento antes da tela de conclusão |
| Um objetivo final claro | Objetivo na tela a cada passo e tela de conclusão |

## Companheiros (0.9.0)

O grupo leva o protagonista e até dois companheiros; os demais recrutados esperam na Estalagem do Ganso Dourado
(livro de hóspedes, ao lado da estalagem). Dados em `data/companions/`, conversas em `data/dialogues/companions.json`.

| Companheiro | Espécie e classe | Onde | Como recrutar |
|---|---|---|---|
| Doran Martelo-Fundo | Anão, Clérigo (Acólito) | Vila de Ribeira | Aceitar a missão de Ione |
| Bruna Pé-Ligeiro | Pequenina, Ladina (Criminosa) | Vila de Ribeira | Concluir "Ameaça na Ruína" (Amara) |
| Lyra Vento-Leste | Elfa, Patrulheira (Soldado) | Clareira | Derrotar o lobo da mata ("A Caça de Lyra") |
| Kael Brasa-Negra | Tiefling, Bruxo (Sábio) | Clareira | Emprestar 15 PO |
| Tarka Rocha-Viva | Golias, Bárbara (Soldado) | Bosque do Riacho | Queda de braço: Atletismo CD 12 (pode repetir) |
| Ignis Escama-Rubra | Draconato, Feiticeiro (Sábio) | Bosque do Riacho | Derrotar Garra-Rubra e soltá-lo |

## Sem depender do desenvolvedor

- Derrota leva ao título; **Continuar** carrega o último salvamento automático (chegada ao mapa, fim de conversa...).
- Fugir do combate é permitido; o gatilho só volta a disparar depois que o jogador sai dele.
- A tela de conclusão aparece uma vez, ao entregar a missão; depois Ione só agradece.
- Teste de ponta a ponta: `tests/quests/test_vertical_slice.gd`; companheiros em `tests/party/test_companions.gd`.
