# Guia do Mestre — como criar missões para As Crônicas de Arghaz

Este guia é para quem vai **escrever** as missões do jogo. Ele mostra o que já existe e o que o jogo consegue fazer
hoje sem programação nova, além de um modelo para entregar cada missão pronta para virar dados.

Leia antes:
- `As Crônicas de Arghaz.md`: a história do mundo escrita pelo autor;
- `docs/HISTORIA.md`: a campanha aprovada, com as Eras, os Atos, a vilã e os companheiros.

---

## 1. O jogo hoje (versão 0.12.0)

- **Regras:** D&D 5ª edição pelo **SRD 5.2.1** (2024). Há 12 classes, 9 espécies, 4 antecedentes, 17 talentos e
  58 magias, com níveis de 1 a 20.
- **Grupo:** o protagonista mais até **2 companheiros**. O jogador controla todos no combate, que é por turnos numa
  grade. Os companheiros fora do grupo esperam na estalagem e acompanham o nível do protagonista.
- **Fluxo:** exploração em mapas, conversas com escolhas, viagens por rotas (com eventos e encontros sorteados),
  combates, descanso e salvamento automático.
- **Onde a história está:** no **Ato I**, "A Garra-Rubra". A próxima etapa é o **Ato II — As Garras**. A busca
  pelas Garras do Arauto começa em Vessa, a cidade humana com a Academia de Mana.

### Mapas, rotas e regiões que já existem

| Tipo | Nome | Observação |
|---|---|---|
| Mapa | Vila de Ribeira | Ione, estalagem (descanso e organização do grupo), Doran e Bruna |
| Mapa | Clareira da Encruzilhada | Amara, lago, ruína com goblin, lobo, Lyra e Kael |
| Mapa | Bosque do Riacho | Acampamento de Garra-Rubra, Tarka e Ignis |
| Rota | Estrada da Vila | Vila ⇄ Clareira |
| Rota | Estrada do Leste | Clareira ⇄ Bosque |
| Região | Campos de Ribeira | Por onde passa a Estrada da Vila |
| Região | Floresta Sussurrante | Por onde passa a Estrada do Leste |

**Mapas novos** (por exemplo, Vessa, Montes de Ferro ou a ruína por dentro) dão trabalho de arte e layout. Na
proposta, diga como é o lugar e o que tem nele, e a equipe desenha.

### Monstros disponíveis (SRD)

| Desafio (ND) | XP | Monstros |
|---|---|---|
| 0 | 10 | rato, aranha |
| 1/8 | 25 | falcão sangrento |
| 1/4 | 50 | lobo, goblin guerreiro, cavalo de montaria |
| 1/2 | 100 | urso-negro, crocodilo, cavalo de guerra, macaco |
| 1 | 200 | lobo atroz, aranha gigante, urso-pardo, chefe goblin (Garra-Rubra) |

Pode pedir outros monstros do SRD 5.2.1; cada um novo é um trabalho de dados e de arte.

### Encontros já montados

| Encontro | Inimigos | Ouro |
|---|---|---|
| Lobo solitário | 1 lobo | — |
| Goblin da ruína | 1 goblin guerreiro | 8 PO |
| Par de lobos | 2 lobos | — |
| Batedor goblin | 1 goblin guerreiro | 5 PO |
| Garra-Rubra | 1 chefe goblin | 40 PO, poção e a Garra Vermelha |

### Eventos de viagem (não combativos)

Arbustos de frutas, árvore caída, mascate na trilha, acampamento abandonado e criança perdida. Cada evento é uma
escolha com teste de perícia e um resultado: XP, item, dano leve ou tempo perdido.

### Personagens

- **NPCs:**
  - **Ione**, chefe de Ribeira: dá a missão principal;
  - **Amara**, guarda da Clareira: dá duas missões.
- **Companheiros recrutáveis:**

| Companheiro | Espécie e classe | Função | Arco na campanha |
|---|---|---|---|
| Doran | anão clérigo | cura | a fé dele (o deus é a memória de um dragão) |
| Bruna | pequenina ladina | dano | quer provar que os pequeninos não são "o povo da colheita" |
| Lyra | elfa patrulheira | dano à distância | fugiu do julgamento dos elfos |
| Kael | tiefling bruxo | magia | o pacto secreto com Vermeth (traição possível no Ato II) |
| Tarka | golias bárbara | tanque | quer desafiar um dragão |
| Ignis | draconato feiticeiro | magia | sangue da Linhagem Vermelha, a chave contra Vermeth |

### Missões que já existem (Ato I)

| Missão | Quem dá | Objetivos | Recompensa |
|---|---|---|---|
| A Garra-Rubra (final do Ato I) | Ione | falar com Amara; derrotar Garra-Rubra | 300 XP, 50 PO |
| Ameaça na Ruína | Amara | derrotar o goblin da ruína | 150 XP, 20 PO |
| Recado ao Bosque | Amara | chegar ao Bosque do Riacho | 100 XP, 10 PO |
| A Caça de Lyra | Lyra | derrotar o lobo | 50 XP, e a Lyra entra no grupo |

---

## 2. O que uma missão pode ter (sem programação nova)

### Objetivos

Uma missão tem um ou mais objetivos de três tipos:

| Tipo | Exemplo |
|---|---|
| **Derrotar um encontro** | "Derrotar o chefe goblin" |
| **Chegar a um mapa** | "Chegar ao Bosque do Riacho" |
| **Conversar com alguém** | "Falar com Amara" |

- Os objetivos podem ser cumpridos **em qualquer ordem** e até **antes** de a missão começar. Nesse caso, já contam.
- A missão fica pronta quando todos estão cumpridos, e o jogador **volta a quem deu** para receber a recompensa.
- Uma missão pode ser marcada como **final**. Ao entregá-la, aparece a tela de conclusão com um **epílogo** escrito
  por você.

### Recompensas

- **XP:** vai para cada membro do grupo.
- **Ouro e itens:** de qualquer item que exista.

### Conversas

Uma conversa é uma árvore de falas, e cada escolha pode:
- **Aparecer só sob uma condição:**
  - situação de uma missão: disponível, ativa, pronta ou concluída;
  - um objetivo cumprido ou não;
  - ter ou não ter um item;
  - ter pelo menos X de ouro;
  - um companheiro recrutado ou disponível;
  - um encontro já vencido;
  - uma cena da história já vista.
- **Fazer uma ou mais ações:** começar ou concluir uma missão, dar um item, recrutar um companheiro ou cobrar ouro.
- **Pedir um teste de perícia:** quem tenta é o membro do grupo com o maior bônus, contra uma CD. Sucesso e falha
  levam a falas diferentes, e dá para permitir tentar de novo.

### Cenas de história

São momentos narrados que acontecem **uma vez só**, quando uma condição é verdadeira:
- **ao chegar** num mapa;
- **depois de descansar**, por exemplo um sonho.

Cada companheiro presente pode ter uma fala própria na cena. São o que deixa a missão viva: use-as para revelações,
pistas e reações do grupo.

### Crônicas

Verbetes do mundo que se desbloqueiam no diário quando uma condição é verdadeira. Use para entregar lore aos poucos.

### Encontros e viagem

- **Encontro fixo:** um combate num ponto do mapa, com os inimigos, o texto de abertura e o loot (ouro e itens).
- **Rota:** uma viagem entre mapas, com eventos e encontros sorteados e acontecimentos garantidos num trecho.

---

## 3. O que ainda **não** existe (avise se a missão precisar)

- Objetivos de **coletar X itens**, **escoltar alguém**, **proteger um lugar** ou com **tempo limite**.
- **Escolhas com consequência de longo prazo** além de missões e flags. Por exemplo, uma reputação com facções.
- **Vários finais** para uma missão. Hoje dá para simular com condições nas conversas.
- **Lojas** e **compra e venda**.
- **Mapas, monstros e NPCs novos** precisam de arte.
- Companheiros falando **fora** das cenas, como conversas de acampamento entre eles.

Tudo isso pode ser construído. Só marque na proposta para entrar no planejamento.

---

## 4. Referência de equilíbrio (nível e XP)

| Nível | XP total |
|---|---|
| 2 | 300 |
| 3 | 900 |
| 4 | 2.700 |
| 5 | 6.500 |
| 6 | 14.000 |
| 7 | 23.000 |
| 8 | 34.000 |
| 9 | 48.000 |
| 10 | 64.000 |

- **Ritmo atual:** o Ato I inteiro dá cerca de 600 a 1.000 XP por personagem. O grupo termina entre o nível **2 e 3**.
- **Sugestão para o Ato II:** levar o grupo do nível **3 ao 5** (cerca de 5.500 XP por personagem no ato todo),
  com encontros de ND 1/2 a 2. O SRD tem a tabela de dificuldade de encontros por nível.
- **Recompensas de missão:**

| Tipo de missão | XP | Ouro |
|---|---|---|
| Secundária | 100 a 300 | 10 a 50 PO |
| Principal | 400 a 1.000 | 50 a 150 PO |

---

## 5. Modelo para entregar cada missão

```
MISSÃO: <nome>
Ato / região: <ex.: Ato II — Vessa>
Tipo: principal | secundária | recrutamento
Quem dá: <NPC> (onde fica)
Resumo (2-3 linhas): <o que está acontecendo e por quê>
Ligação com a história: <Garras, Vermeth, linhagens, arco de um companheiro...>

Objetivos (em ordem sugerida):
  1. <derrotar encontro | chegar ao mapa | falar com alguém> — <detalhe>
  2. ...

Conversas:
  - <NPC>: falas principais e escolhas (com condições, testes de perícia e CD, se houver)
Cenas de história: <momento — chegada ou descanso, onde> <texto> <falas dos companheiros>
Crônica desbloqueada: <título e texto curto> (opcional)

Encontros: <inimigos e quantidade, onde, texto de abertura, loot>
Recompensa: <XP> · <PO> · <itens>
Nível sugerido: <ex.: 3-4>
Precisa de algo novo? <mapa, monstro, NPC, tipo de objetivo, loja...>
```

**Exemplo curto (Ato II):**

```
MISSÃO: O Livro do Templo
Ato / região: Ato II — Vessa
Tipo: principal · Quem dá: Arquivista da Academia de Mana
Resumo: A Garra Vermelha reage ao livro do templo de Ribeira. A arquivista pede três páginas
        roubadas por cultistas de Vermeth antes de explicar o que são as Garras.
Ligação: Vermeth, Kael (o cultista o reconhece), Ignis (sente a Garra perto das páginas).
Objetivos: 1. Derrotar os cultistas no porão (encontro) 2. Falar com a Arquivista
Cena: ao chegar ao porão — o cultista chama Kael de "irmão de pacto". Fala do Kael e do Ignis.
Crônica: "As Garras do Arauto" (quantas são e onde estariam)
Recompensa: 450 XP · 60 PO · Página do Livro
Nível: 3-4 · Precisa de algo novo? Mapa de Vessa e do porão, NPC Arquivista, monstro cultista.
```
