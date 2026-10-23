# PROJECT MASTER SPECIFICATION — FANTASY RPG 2D

**Versão:** 1.1  
**Idioma do projeto:** português brasileiro, com arquitetura preparada para localização futura  
**Motor:** Godot 4.x estável  
**Linguagem:** GDScript tipado  
**Plataforma inicial:** navegador desktop  
**Agente de desenvolvimento:** Claude Code  
**Modelo de regras:** D&D 5.5e / 2024, baseado no SRD 5.2.1  
**Modelo de produção artística:** imagens e assets criados por IA e ferramentas gratuitas  
**Orçamento inicial:** R$ 0  
**Modo inicial:** single-player  
**Multiplayer:** possibilidade futura, não implementado no MVP

---

# PARTE I — VISÃO DO PRODUTO

## 1. Missão

Construir um RPG 2D de fantasia com exploração em tempo real, combate por turnos, criação e evolução de personagens, viagens, encontros aleatórios, missões, inventário, magias e um mundo original.

O jogo deve oferecer profundidade mecânica inspirada nas regras de D&D 5.5e, sem depender de pagamentos à Wizards of the Coast, serviços de infraestrutura pagos ou ferramentas de IA pagas obrigatórias.

O projeto será desenvolvido por meio de vibecoding, utilizando Claude Code como agente de programação. O agente deve atuar como arquiteto, programador, revisor de código, testador e auxiliar de produção.

A produção será incremental. O objetivo é entregar um jogo funcional, e não somente telas bonitas ou demonstrações sem sistemas integrados.

## 2. Princípios inegociáveis

1. Custo inicial de R$ 0.
2. Nenhum serviço pago obrigatório.
3. Nenhuma licença paga à Wizards of the Coast.
4. Nenhum conteúdo protegido copiado sem autorização.
5. Arte original produzida por IA ou ferramentas gratuitas.
6. Código organizado, modular e documentado.
7. Regras de RPG centralizadas e testáveis.
8. Testes reais antes de declarar uma funcionalidade concluída.
9. Exportação para navegador validada desde o início.
10. Salvamento local independente de backend.
11. Controle de versão com Git.
12. Nenhuma funcionalidade existente deve ser removida silenciosamente.
13. Nenhuma alegação falsa de que um teste, exportação ou integração funcionou.
14. Nenhum consumo de serviços externos, créditos ou recursos pagos sem autorização expressa.
15. Nenhuma tentativa de implementar o jogo inteiro em uma única tarefa.

Se uma decisão ameaçar esses princípios, o agente deve explicar o risco e apresentar uma alternativa gratuita.

## 3. Identidade do jogo

O jogo terá um universo próprio de fantasia medieval, com identidade visual e narrativa originais.

O nome comercial definitivo ainda não está definido. Utilize um identificador provisório, `PROJECT_NAME`, até que o desenvolvedor escolha o nome.

O projeto deve evitar depender de Forgotten Realms, personagens oficiais, histórias oficiais, marcas, logotipos ou imagens de livros de D&D.

A inspiração está na estrutura de RPG de fantasia, na exploração, nas decisões dos personagens e nas mecânicas autorizadas, não na reprodução integral de uma franquia.

### Direção de gameplay

- Exploração em mapas 2D.
- Visão superior, com câmera seguindo o personagem.
- Movimento livre no mapa, com colisões.
- Combates em uma cena própria, com turnos e movimentação tática.
- Grupo de aventureiros controlado pelo jogador.
- Companheiros controlados por IA determinística no combate.
- Viagens com encontros, acontecimentos, recursos e escolhas.
- NPCs, lojas, missões, masmorras e chefes.
- Progressão de personagem e equipamentos.
- Salvamento local.
- Interface legível e adequada ao navegador desktop.

A direção visual inicial será pixel art de fantasia, com paleta coerente, silhuetas legíveis, cenários detalhados e personagens visualmente reconhecíveis.

Essa direção poderá ser refinada após a produção dos primeiros sprites de referência.

---

# PARTE II — LICENÇAS E CONTEÚDO

## 4. Política de regras

Utilizar como referência o SRD 5.2.1, correspondente às regras revisadas de 2024.

Fonte oficial: https://www.dndbeyond.com/srd

O conteúdo do SRD 5.2.1 está disponível sob Creative Commons Attribution 4.0 International (CC BY 4.0). A utilização exige atribuição adequada e cumprimento dos termos aplicáveis.

Texto oficial de atribuição para inclusão no produto, conforme o SRD:

> This work includes material from the System Reference Document 5.2 (“SRD 5.2”) by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.

O responsável pelo projeto deverá conferir o texto de atribuição e os requisitos aplicáveis à versão específica do SRD utilizada, mantendo a atribuição em local apropriado no jogo e na documentação.

### Regras de conteúdo

- Utilizar somente mecânicas e conteúdo autorizado pelo SRD ou material original.
- Não presumir que todo o conteúdo dos livros oficiais esteja disponível.
- Não importar suplementos completos de fontes não autorizadas.
- Não copiar textos extensos de livros ou sites.
- Não reproduzir ilustrações, mapas, logotipos ou design visual oficial.
- Não utilizar nomes próprios, personagens ou cenários protegidos apenas por estarem associados à franquia.
- Não afirmar que o jogo é um produto oficial de D&D.
- Não presumir que todo conteúdo criado por IA está automaticamente livre de direitos de terceiros.

Criar `docs/CONTENT_LICENSES.md` e `THIRD_PARTY_NOTICES.md`.

Para cada conteúdo de terceiros, registrar:
- Nome do conteúdo.
- Fonte original.
- Autor ou titular, quando identificado.
- Licença.
- URL.
- Data de obtenção.
- Modificações realizadas.
- Obrigações de atribuição.

Se uma licença não puder ser verificada, não incluir o asset na versão distribuída.

## 5. Sistema de regras

A lógica de regras deverá ser independente da apresentação visual.

Implementar progressivamente, respeitando o conteúdo autorizado:

- Atributos e modificadores.
- Testes de atributo.
- Testes de perícia.
- Testes de resistência.
- Proficiência.
- Vantagem e desvantagem.
- Classe de Armadura.
- Pontos de vida.
- Iniciativa.
- Ataques e dano.
- Críticos conforme a edição adotada.
- Condições.
- Descanso e recuperação de recursos.
- Experiência e níveis.
- Equipamentos.
- Magias e recursos de classe.
- Ações, ações bônus e reações.
- Movimento em combate.
- Resistências e vulnerabilidades, conforme aplicáveis.

Não misturar silenciosamente regras de 2014 e 2024.

Manter `docs/RULES_POLICY.md` com as regras implementadas, as fontes, as adaptações e as pendências.

Cada regra importante deverá ter testes automatizados.

---

# PARTE III — ARQUITETURA TÉCNICA

## 6. Stack obrigatória

- Godot 4.x estável.
- GDScript tipado.
- Compatibility Renderer.
- Exportação Web com WebAssembly e WebGL 2.
- Git.
- Claude Code para implementação.
- Arquivos JSON e recursos nativos do Godot para dados.
- Salvamento local no MVP.
- Ferramentas gratuitas para produção e organização de assets.

Não usar C# no projeto inicial.

Não adicionar React, Node.js, PostgreSQL, Supabase ou outro backend sem uma necessidade real aprovada pelo desenvolvedor.

Não adicionar dependências externas para funções já disponíveis no Godot.

Antes de configurar o projeto, verificar a versão do motor e a compatibilidade da exportação web.

## 7. Arquitetura modular

Separar as seguintes camadas:

### Apresentação
Responsável por cenas, sprites, animações, câmera, HUD, menus e efeitos visuais.

### Sistemas de jogo
Responsáveis por exploração, combate, viagens, missões, inventário e progressão.

### Motor de regras
Responsável por cálculos e resolução das regras.

### Dados de conteúdo
Responsáveis por espécies, classes, subclasses, monstros, itens, magias, regiões e encontros.

### Persistência
Responsável por salvar, carregar, validar e versionar o progresso.

### Ferramentas de desenvolvimento
Responsáveis por testes, validação de dados, auditoria de assets e exportação.

## 8. Módulos principais

Criar e manter os seguintes módulos lógicos:

- `RulesEngine`
- `CharacterSystem`
- `CombatManager`
- `ExplorationManager`
- `EncounterDirector`
- `TravelSystem`
- `InventorySystem`
- `QuestManager`
- `DialogueSystem`
- `SaveManager`
- `ContentRegistry`
- `PartyManager`
- `AssetRegistry`
- `AudioManager`
- `SettingsManager`

Cada módulo deve ter uma responsabilidade clara.

A interface não deve implementar regras de combate diretamente.

O `CombatManager` controla a sequência do combate. O `RulesEngine` calcula resultados. O sistema de apresentação apenas envia comandos e exibe os resultados.

## 9. Estrutura de pastas

Organizar o projeto desta forma:

```text
fantasy-rpg/
├── project.godot
├── README.md
├── CLAUDE.md
├── LICENSE
├── THIRD_PARTY_NOTICES.md
├── .gitignore
├── docs/
│   ├── GAME_DESIGN.md
│   ├── ARCHITECTURE.md
│   ├── RULES_POLICY.md
│   ├── CONTENT_LICENSES.md
│   ├── ART_BIBLE.md
│   ├── ASSET_PIPELINE.md
│   ├── ROADMAP.md
│   └── CHANGELOG.md
├── assets/
│   ├── characters/
│   ├── portraits/
│   ├── enemies/
│   ├── bosses/
│   ├── tilesets/
│   ├── environments/
│   ├── items/
│   ├── icons/
│   ├── effects/
│   ├── ui/
│   └── audio/
├── scenes/
│   ├── main/
│   ├── menus/
│   ├── exploration/
│   ├── combat/
│   ├── characters/
│   ├── enemies/
│   ├── npcs/
│   ├── ui/
│   └── world/
├── scripts/
│   ├── core/
│   ├── rules/
│   ├── characters/
│   ├── combat/
│   ├── exploration/
│   ├── encounters/
│   ├── travel/
│   ├── inventory/
│   ├── quests/
│   ├── dialogue/
│   ├── party/
│   ├── persistence/
│   ├── assets/
│   └── ui/
├── data/
│   ├── species/
│   ├── classes/
│   ├── subclasses/
│   ├── spells/
│   ├── items/
│   ├── monsters/
│   ├── encounters/
│   ├── regions/
│   ├── quests/
│   └── localization/
├── tools/
│   ├── asset_validation/
│   ├── content_validation/
│   └── export/
├── tests/
│   ├── rules/
│   ├── combat/
│   ├── characters/
│   ├── persistence/
│   └── integration/
└── exports/
    └── web/
```

Não criar arquivos vazios apenas para preencher a estrutura. Criar cada diretório conforme a etapa correspondente.

## 10. Dados e identificadores

Separar dados de conteúdo da lógica de execução.

Cada conteúdo deverá ter um identificador estável, por exemplo:

- `species.original_forestborn`
- `class.fighter`
- `item.healing_potion`
- `monster.forest_wolf`
- `spell.example_spell`
- `region.whispering_forest`

Esses identificadores são exemplos de nomenclatura interna, não uma declaração de que o conteúdo já foi implementado.

Os dados deverão ser validados antes de serem utilizados.

Verificar:
- Campos obrigatórios.
- Tipos de dados.
- Valores válidos.
- Referências a outros conteúdos.
- Identificadores duplicados.
- Campos desconhecidos.
- Dependências ausentes.

Falhas de conteúdo devem produzir mensagens úteis de diagnóstico.

---

# PARTE IV — DIREÇÃO DE ARTE E PRODUÇÃO POR IA

## 11. Política geral de arte

Todos os assets visuais poderão ser produzidos por IA ou por ferramentas gratuitas.

O projeto não deve depender de um único gerador de imagens, de uma API paga ou de créditos de geração pagos.

O Claude Code deve ser responsável por organizar o pipeline, criar especificações dos assets, validar arquivos e integrá-los ao Godot.

O Claude Code não deve presumir que consegue gerar imagens diretamente. Quando não houver uma ferramenta de imagem disponível, deverá produzir prompts de geração, instruções e arquivos de referência, sem alegar que a imagem foi criada.

É permitido utilizar:
- Ferramentas gratuitas de geração de imagem, conforme disponibilidade.
- Ferramentas locais de edição de pixel art.
- Scripts de processamento de imagens.
- Sprites provisórios feitos com formas simples.
- Assets originais criados manualmente.
- Assets de terceiros com licença comprovadamente compatível.

Não utilizar automaticamente imagens retiradas de mecanismos de busca ou de jogos comerciais.

## 12. Bíblia visual

Criar `docs/ART_BIBLE.md` antes de produzir um grande volume de arte.

A bíblia visual deverá definir:

- Direção artística.
- Paleta principal.
- Paletas por região.
- Tamanho-base dos sprites.
- Escala dos personagens.
- Proporções de corpo.
- Nível de detalhe.
- Contorno.
- Iluminação.
- Sombras.
- Perspectiva.
- Convenções de animação.
- Padrão dos retratos.
- Estilo de ícones.
- Design da interface.
- Regras de transparência.
- Convenções de nomes.
- Restrições de conteúdo.

### Direção inicial

Adotar pixel art de fantasia medieval com leitura clara em baixa resolução.

Os personagens devem possuir silhuetas distintas, equipamentos reconhecíveis, animações legíveis e uma paleta que harmonize com o ambiente.

Os cenários devem apresentar profundidade visual por meio de camadas, variações de terreno, elementos de composição e iluminação simulada.

Evitar a mistura de sprites pixelados com personagens de ilustração digital realista.

Não misturar estilos de arte entre diferentes regiões sem uma justificativa artística documentada.

## 13. Especificação de assets

Definir um padrão inicial, ajustável por categoria:

### Personagens de exploração
- Sprite-base de 32 × 32 pixels ou 48 × 48 pixels, conforme a escala escolhida.
- Fundo transparente.
- Perspectiva top-down ou top-down com leve projeção frontal.
- Silhueta legível em escala reduzida.
- Animações direcionais.
- Pivô e área de colisão consistentes.

### Animações
Prever, conforme a necessidade:

- Idle.
- Walk.
- Run, se houver corrida.
- Attack.
- Hit.
- Death.
- Cast, quando aplicável.
- Interact, quando aplicável.

Definir antecipadamente os quadros, a ordem e a taxa de animação de cada ação.

### Retratos
- Resolução padronizada.
- Rosto e ombros.
- Fundo controlado.
- Expressão compatível com o personagem.
- Identidade facial consistente entre imagens.

### Tilesets
- Grade uniforme.
- Tiles de terreno.
- Caminhos.
- Bordas e transições.
- Paredes e obstáculos.
- Elementos decorativos.
- Objetos interativos.
- Regras de colisão documentadas.

### Ícones
- Dimensões padronizadas.
- Fundo transparente.
- Contraste adequado.
- Silhuetas simples.
- Legibilidade em tamanhos pequenos.
- Sem textos incorporados quando não forem necessários.

Os tamanhos acima são padrões iniciais de produção, não exigências universais para todos os assets.

## 14. Pipeline de geração de imagens

O pipeline deverá funcionar assim:

1. Definir a necessidade do asset.
2. Criar uma especificação técnica.
3. Criar o prompt de geração.
4. Gerar a imagem em uma ferramenta disponível.
5. Verificar a consistência visual.
6. Recortar ou processar a imagem.
7. Ajustar transparência e dimensões.
8. Criar spritesheets ou quadros de animação.
9. Validar o arquivo.
10. Registrar origem e licença.
11. Integrar o asset ao Godot.
12. Verificar o resultado no jogo.
13. Atualizar o catálogo de assets.

Não considerar uma imagem concluída apenas porque o arquivo foi gerado.

O asset precisa ser utilizável no jogo.

## 15. Prompt-base para arte

Criar um catálogo de prompts em `docs/ASSET_PIPELINE.md`.

Utilizar uma estrutura semelhante a esta para cada solicitação de arte:

> Crie um asset original para um RPG 2D de fantasia medieval em pixel art. Categoria: [categoria]. Identidade visual: seguir a bíblia visual do projeto. Dimensões de saída: [dimensões]. Perspectiva: [perspectiva]. Paleta: [paleta]. Silhueta: [descrição]. Equipamentos: [descrição]. Iluminação: [padrão]. Fundo: transparente quando aplicável. Não incluir texto, marca d'água, logotipo, interface ou elementos externos à área solicitada. Não imitar um personagem, arte, franquia ou artista específico. O resultado deve ser um asset original e legível na escala final do jogo.

O prompt deverá ser adaptado à categoria específica.

Para spritesheets, especificar expressamente:
- Número de linhas.
- Número de colunas.
- Dimensões exatas de cada quadro.
- Ordem dos quadros.
- Direções.
- Sequência de animação.
- Espaçamento zero ou especificado.
- Fundo transparente.
- Ausência de elementos que atravessem os limites entre quadros.

Se o gerador não conseguir produzir uma spritesheet tecnicamente correta, gerar imagens individuais e utilizar ferramentas gratuitas para organizar os quadros.

## 16. Consistência entre imagens

Manter referências internas dos personagens, incluindo:

- Nome.
- Identificador.
- Descrição física.
- Paleta.
- Roupa.
- Armadura.
- Armas.
- Silhueta.
- Proporções.
- Traços faciais.
- Versões aprovadas.
- Arquivos de referência.

A geração de uma nova imagem do mesmo personagem deve partir das referências visuais aprovadas, quando a ferramenta permitir.

Não aceitar automaticamente uma imagem que altere a identidade de um personagem recorrente.

A consistência visual deve ser verificada antes da integração.

## 17. Catálogo e auditoria de assets

Criar um catálogo central com os metadados de cada asset.

Cada registro deverá conter, quando aplicável:

- `asset_id`
- `category`
- `file_path`
- `dimensions`
- `format`
- `transparency`
- `animation_frames`
- `animation_fps`
- `source_type`
- `source_url`
- `license`
- `prompt_reference`
- `approval_status`
- `notes`

Criar ferramentas para detectar:
- Arquivos ausentes.
- Referências quebradas.
- Dimensões inesperadas.
- Spritesheets incompatíveis.
- Assets duplicados.
- Formatos não suportados.
- Arquivos sem licença registrada.
- Assets não utilizados.

Não apagar automaticamente arquivos apenas porque parecem não estar em uso. Produzir relatório e solicitar confirmação antes de remoções potencialmente destrutivas.

## 18. Integração de arte no Godot

Utilizar os recursos nativos do Godot para:

- Sprite2D.
- AnimatedSprite2D.
- SpriteFrames.
- TileMapLayer.
- AtlasTexture, quando apropriado.
- Animações e efeitos visuais.
- Importação de texturas.
- Configurações de filtro e mipmaps adequadas à pixel art.

Para pixel art:
- Desabilitar suavização quando necessário.
- Evitar interpolação visual que borre os pixels.
- Manter escala consistente.
- Testar alinhamento de pixels.
- Evitar artefatos nas bordas dos tiles.
- Verificar o resultado em resoluções diferentes.

Não assumir que uma imagem gerada em alta resolução pode ser usada diretamente como sprite final.

Quando necessário, produzir uma versão reduzida, limpa e validada.

---

# PARTE V — SISTEMAS DE JOGO

## 19. Exploração

Implementar:

- Movimento em tempo real.
- Colisões.
- Câmera.
- Interação com objetos.
- NPCs.
- Transição entre mapas.
- Pontos de interesse.
- Áreas de combate.
- Entradas de masmorras.
- Rotas de viagem.
- Áreas bloqueadas por missões ou condições.

A movimentação deverá continuar responsiva durante a exploração.

O jogo deverá manter o estado do personagem ao transitar entre cenas.

## 20. Viagens e encontros aleatórios

Criar um `TravelSystem` que controle:

- Origem e destino.
- Duração da viagem.
- Trechos de rota.
- Recursos consumidos.
- Descanso.
- Eventos.
- Probabilidade de encontros.
- Perigos da região.
- Possíveis consequências.

Criar um `EncounterDirector` que selecione encontros a partir de dados configuráveis.

Os encontros não devem ser completamente arbitrários.

Considerar:
- Região.
- Nível de desafio planejado.
- Grupo atual.
- Estado da missão.
- Horário ou condição ambiental, se aplicável.
- Histórico recente de encontros.
- Eventos já resolvidos.

Não garantir equilíbrio perfeito por fórmulas sem testes.

Permitir eventos sem combate, incluindo descobertas, NPCs, recursos, escolhas e perigos ambientais.

## 21. Combate

O combate será por turnos, separado da exploração.

Implementar:
- Preparação do encontro.
- Posicionamento.
- Iniciativa.
- Ordem de turnos.
- Ações disponíveis.
- Movimento tático.
- Ataques.
- Testes e resistências.
- Dano.
- Condições.
- Recursos.
- Morte ou derrota.
- Vitória.
- Fuga, quando permitida.
- Recompensas.
- Retorno à exploração.

O fluxo deverá ser explícito e previsível.

Não permitir que dois participantes ajam simultaneamente por erro de estado.

Validar comandos recebidos de personagens, verificando se a ação é permitida naquele momento.

## 22. Personagens e progressão

Criar sistemas de dados para:
- Espécies.
- Classes.
- Subclasses.
- Atributos.
- Perícias.
- Proficiências.
- Equipamentos.
- Talentos e características autorizados.
- Experiência.
- Níveis.
- Recursos.
- Magias.
- Resistências.
- Condições.

Não implementar todas as opções de conteúdo de uma só vez.

A progressão deve ser orientada por dados sempre que isso não complicar excessivamente o código.

As regras de progressão devem ser verificáveis por testes.

## 23. Grupo de aventureiros

Permitir que o jogador gerencie um grupo.

Implementar progressivamente:
- Recrutamento de companheiros.
- Formação do grupo.
- Ficha dos companheiros.
- Equipamentos.
- Recursos.
- Comportamento no combate.
- Condições de vitória e derrota.
- Diálogos e eventos associados aos companheiros.

No MVP, a IA dos companheiros deve ser simples, determinística e baseada em prioridades.

Não utilizar APIs de IA generativa em tempo de execução.

## 24. Missões e diálogos

Criar missões baseadas em estados e objetivos.

Cada missão poderá ter:
- Identificador.
- Descrição.
- Objetivos.
- Condições de ativação.
- Etapas.
- Condições de conclusão.
- Recompensas.
- Consequências.
- Referências a NPCs, regiões e itens.

Os diálogos devem ser armazenados separadamente do código.

Evitar missões que dependam de referências quebradas ou objetivos impossíveis de concluir.

## 25. Inventário

Implementar:
- Itens empilháveis, quando aplicável.
- Equipamentos.
- Armas.
- Armaduras.
- Consumíveis.
- Recompensas.
- Uso de itens.
- Validação das condições de utilização.
- Atualização de atributos derivados.
- Remoção e adição de itens.
- Salvamento do inventário.

O sistema de inventário deve ser independente da tela visual.

---

# PARTE VI — SALVAMENTO E PREPARAÇÃO PARA MULTIPLAYER

## 26. Salvamento local e autosave

O MVP deve ter **um único slot de salvamento principal**, suficiente para a primeira versão. Não implementar múltiplos slots nesta etapa.

### Requisitos obrigatórios

- Usar primeiro o mecanismo de armazenamento local do Godot (`user://`), verificando o comportamento real no build para navegador.
- Implementar **autosave** em momentos seguros e importantes, sem salvar a cada frame:
  - após concluir uma missão ou objetivo relevante;
  - após resolver um combate e aplicar seus resultados;
  - ao concluir uma transição de região ou área;
  - após escolhas narrativas importantes;
  - em pontos seguros definidos pelo jogo.
- O autosave deve ocorrer somente quando o estado do jogo estiver consistente. Evitar salvar estados parciais de combate, transições incompletas ou operações que possam deixar o arquivo incoerente.
- Exibir um indicador discreto de salvamento em andamento e um feedback claro em caso de sucesso ou falha, sem interromper desnecessariamente a experiência.
- Evitar gravações excessivas. Agrupar alterações e usar uma estratégia controlada de autosave.
- Incluir versão de esquema dos dados salvos e preparar migrações compatíveis para futuras atualizações.
- Validar os dados ao carregar; tratar arquivos ausentes, inválidos, incompletos ou corrompidos com mensagens úteis e uma recuperação segura quando possível.
- Reduzir o risco de corromper o save durante uma gravação. Usar escrita temporária e substituição segura quando suportado; manter uma cópia de recuperação se isso for viável no ambiente-alvo.
- Não sobrescrever automaticamente um save válido com dados inválidos ou com um estado incompleto.
- Disponibilizar uma opção manual de **“Salvar agora”** e uma opção de **“Continuar”** para carregar o progresso existente, se houver.
- Exportação/importação manual do save fica fora do escopo inicial e pode ser considerada em uma versão futura.
- Informar claramente quando o armazenamento local não estiver disponível ou quando a gravação falhar. Nunca afirmar que o progresso foi salvo se a operação não tiver sido confirmada.
- Não exigir conta, servidor, banco de dados remoto, serviço pago ou conexão constante com a internet para salvar o progresso.

### Persistência no navegador

- Confirmar por testes que o progresso continua disponível após recarregar a página e após fechar e reabrir o mesmo navegador, usando o mesmo perfil e endereço do jogo.
- Se `user://` não persistir de forma confiável no build Web, pesquisar e implementar uma alternativa gratuita compatível, como integração com IndexedDB, somente após avaliar a compatibilidade com a versão do Godot e com a exportação Web.
- Documentar que o armazenamento é local ao navegador/perfil e ao endereço de hospedagem; não sincroniza automaticamente entre dispositivos.
- Informar que limpar os dados do site/navegador pode apagar o progresso local.
- Não adicionar plugins ou dependências pagas obrigatórias para esse sistema.

## 27. Preparação para multiplayer

Não implementar multiplayer no MVP.

Entretanto:
- Evitar dependência excessiva da interface.
- Separar comandos de jogo de efeitos visuais.
- Utilizar identificadores estáveis.
- Manter o estado do jogo serializável.
- Centralizar regras.
- Evitar que o resultado de combate dependa do tempo de animação.
- Permitir sementes aleatórias configuráveis em testes.
- Não presumir que o cliente será confiável em um futuro multiplayer.

Qualquer implementação futura deverá avaliar servidor autoritativo, sincronização, persistência remota, latência e proteção contra trapaças.

---

# PARTE VII — QUALIDADE E SEGURANÇA

## 28. Testes

Criar testes para:
- Modificadores de atributos.
- Testes de perícia.
- Ataques.
- Dano.
- Iniciativa.
- Condições.
- Turnos.
- Progressão.
- Inventário.
- Encontros.
- Salvamento.
- Carregamento.
- Validação de conteúdo.
- Transição entre exploração e combate.

Utilizar testes automatizados adequados ao projeto Godot.

Se uma biblioteca de testes for utilizada, verificar sua licença, compatibilidade e custo. Preferir ferramentas gratuitas e open source.

Não afirmar que testes passaram sem executá-los.

Não substituir falhas reais por testes que apenas verificam se um arquivo existe.

## 29. Segurança e integridade do projeto

Mesmo sendo single-player:
- Validar dados carregados.
- Evitar executar conteúdo arbitrário vindo de arquivos.
- Não armazenar segredos ou credenciais no projeto.
- Não incluir chaves de API.
- Não enviar dados do jogador a serviços externos sem autorização.
- Não criar telemetria oculta.
- Não incluir dependências desconhecidas sem justificativa.
- Não executar comandos destrutivos sem explicar o impacto.
- Não apagar arquivos sem confirmação quando houver risco de perda de trabalho.

## 30. Desempenho

Priorizar desempenho no navegador desktop.

Evitar:
- Carregar todos os assets de uma vez sem necessidade.
- Criar milhares de nós desnecessários.
- Executar cálculos complexos em todos os frames.
- Gerar assets pesados sem compressão ou otimização.
- Utilizar plugins sem necessidade.
- Implementar física complexa quando colisões simples forem suficientes.

Monitorar:
- Tempo de carregamento.
- Tamanho do pacote.
- Consumo de memória.
- Taxa de quadros.
- Número de sprites ativos.
- Desempenho em combates.

Não estabelecer metas de desempenho sem medir o resultado em um ambiente definido.

---

# PARTE VIII — INTERFACE E EXPERIÊNCIA DO JOGADOR

## 31. Interface

Criar uma interface original, coerente com a direção artística.

Telas planejadas:
- Menu inicial.
- Novo jogo.
- Criação de personagem.
- Exploração.
- Ficha.
- Inventário.
- Grupo.
- Diário de missões.
- Mapa.
- Diálogos.
- Combate.
- Vitória e derrota.
- Configurações.
- Salvamento e carregamento.

A interface deve ser legível em resoluções desktop comuns.

Utilizar tipografia com licença adequada e boa legibilidade.

Não desenhar textos importantes diretamente dentro de imagens geradas por IA. Renderizar textos por meio dos controles da interface, permitindo correções, localização e acessibilidade.

## 32. Usabilidade

- Controles claros.
- Feedback visual de ações.
- Indicação de alvos válidos.
- Informação sobre alcance.
- Mensagens de erro úteis.
- Confirmação para ações destrutivas.
- Menus navegáveis.
- Opções básicas de áudio e volume.
- Configurações persistentes.
- Ajuda contextual para as regras.

Evitar depender exclusivamente de cor para comunicar estados importantes.

---

# PARTE IX — ROADMAP

## 33. Fase 0 — Fundação técnica

Objetivos:
- Verificar o ambiente.
- Confirmar a versão do Godot.
- Criar o projeto.
- Configurar Git.
- Criar a estrutura mínima.
- Criar uma cena inicial.
- Exportar uma versão mínima para Web.
- Testar no navegador.
- Criar documentação inicial.

Critério de conclusão:
O projeto abre no Godot e funciona no navegador sem erros críticos conhecidos.

## 34. Fase 1 — Primeiro mapa

Objetivos:
- Criar um personagem provisório.
- Criar um mapa simples.
- Implementar movimento.
- Implementar colisões.
- Implementar câmera.
- Implementar interação básica.
- Estabelecer o primeiro padrão visual.

Critério de conclusão:
O personagem pode andar pelo mapa, colidir com obstáculos e interagir com pelo menos um objeto.

## 35. Fase 2 — Modelo de personagens

Objetivos:
- Criar modelo de dados.
- Implementar atributos.
- Implementar ficha.
- Implementar criação básica de personagem.
- Implementar dados de equipamento.
- Criar testes de regras.

Critério de conclusão:
O personagem pode ser criado, consultado e salvo sem inconsistências conhecidas.

## 36. Fase 3 — Combate

Objetivos:
- Criar cena de combate.
- Implementar iniciativa.
- Implementar turnos.
- Implementar ataques e dano.
- Implementar inimigos.
- Implementar vitória e derrota.
- Testar regras.

Critério de conclusão:
Um combate completo pode ser iniciado, resolvido e encerrado sem quebrar o estado do jogo.

## 37. Fase 4 — Viagens e encontros

Objetivos:
- Implementar regiões.
- Implementar rotas.
- Implementar eventos.
- Implementar encontros aleatórios.
- Implementar transição entre exploração e combate.
- Implementar retorno ao mapa.

Critério de conclusão:
Uma viagem pode gerar eventos, iniciar combates e continuar após a resolução dos encontros.

## 38. Fase 5 — Progressão e conteúdo

Objetivos:
- Implementar inventário.
- Implementar missões.
- Implementar NPCs.
- Implementar progressão.
- Adicionar conteúdo autorizado e original.
- Integrar os primeiros assets finais.

Critério de conclusão:
O jogador pode explorar, lutar, receber recompensas, concluir uma missão e continuar a aventura.

## 39. Fase 6 — Salvamento e integração

Objetivo: tornar a progressão persistente e confiável no navegador.

Entregas:
- um único slot de save para o MVP;
- autosave em eventos importantes e pontos seguros;
- comando manual “Salvar agora” e opção “Continuar”;
- dados salvos com versão de esquema e estratégia de migração;
- validação dos dados carregados e tratamento de arquivos corrompidos/incompletos;
- escrita segura e recuperação de save quando viável;
- mensagens de sucesso/falha de salvamento;
- teste de persistência ao recarregar a página e ao fechar/reabrir o navegador;
- avaliação de IndexedDB somente se a persistência Web do `user://` não atender aos critérios;
- documentação das limitações do armazenamento local e de que limpar os dados do site pode apagar o progresso.

Não implementar múltiplos slots de save no MVP.

## 40. Fase 7 — Vertical slice

Construir uma pequena experiência completa contendo:
- Uma vila.
- Uma região de exploração.
- Uma rota de viagem.
- Um encontro não combativo.
- Um combate.
- Uma missão.
- Um NPC.
- Uma recompensa.
- Um salvamento.
- Um objetivo final claro.

Critério de conclusão:
Uma pessoa consegue iniciar o jogo, entender o objetivo, jogar o trecho e chegar a uma conclusão sem depender do desenvolvedor para corrigir o estado do jogo.

## 41. Fase 8 — Publicação

Objetivos:
- Exportar para Web.
- Verificar os arquivos.
- Testar a hospedagem.
- Verificar licenças.
- Preparar documentação.
- Registrar limitações.
- Publicar apenas após validação.

A publicação deverá usar uma hospedagem gratuita compatível, respeitando suas condições e limites.

Não garantir que uma hospedagem gratuita seja ilimitada ou permanente.

---

# PARTE X — REGRAS DE TRABALHO DO CLAUDE CODE

## 42. Fluxo obrigatório por tarefa

Antes de cada implementação:

1. Inspecionar o estado atual do projeto.
2. Ler as instruções relevantes.
3. Identificar arquivos e sistemas afetados.
4. Descrever brevemente o plano.
5. Verificar dependências e compatibilidade.
6. Implementar apenas o escopo acordado.
7. Executar os testes pertinentes.
8. Verificar os erros do Godot.
9. Atualizar documentação.
10. Resumir o resultado real.

Não reescrever grandes áreas quando uma alteração localizada resolver o problema.

Não modificar arquivos não relacionados sem justificativa.

Não instalar dependências automaticamente sem avaliar sua necessidade.

Não presumir que a geração de imagem, exportação, hospedagem ou testes foram bem-sucedidos.

## 43. Gestão de contexto

Manter `CLAUDE.md` curto o suficiente para ser útil como instrução persistente.

Manter os detalhes técnicos nos arquivos de documentação apropriados.

Ao terminar uma sessão:
- Atualizar `ROADMAP.md`.
- Registrar decisões arquiteturais importantes.
- Registrar erros conhecidos.
- Registrar a próxima tarefa concreta.
- Informar os arquivos modificados.
- Informar os testes executados.
- Registrar o estado do repositório.

Não duplicar documentos inteiros dentro de `CLAUDE.md`.

## 44. Critérios de aceitação

Uma tarefa só está concluída quando:
- Os requisitos definidos foram atendidos.
- O projeto continua abrindo.
- Os testes aplicáveis foram executados.
- Os erros encontrados foram registrados.
- A documentação foi atualizada.
- Os arquivos estão versionados ou prontos para versionamento.
- Não existem dependências pagas introduzidas inadvertidamente.
- Os assets novos estão catalogados e possuem origem documentada.

Se algum requisito não puder ser atendido, registrar o motivo e apresentar a alternativa mais simples.

---

# PARTE XI — PRIMEIRA EXECUÇÃO

- O jogo possui um único slot de salvamento no MVP e o autosave ocorre apenas em eventos importantes e estados consistentes.
- O jogador consegue continuar de um save válido e solicitar salvamento manual.
- O progresso persiste após recarregar a página e após fechar/reabrir o mesmo navegador, conforme os testes no build Web.
- Falhas de armazenamento são comunicadas com clareza; o jogo não declara sucesso sem confirmação.
- Saves inválidos ou corrompidos não sobrescrevem silenciosamente um save válido.

## 45. Instrução inicial

Não implemente o jogo inteiro agora.

Comece pela Fase 0.

Execute as seguintes tarefas:

1. Inspecione o ambiente de desenvolvimento.
2. Confirme a disponibilidade do Godot e do Git.
3. Verifique a versão do Godot.
4. Confirme a disponibilidade dos templates de exportação web.
5. Verifique se existe um repositório ou projeto anterior na pasta.
6. Não sobrescreva arquivos existentes sem verificar seu conteúdo.
7. Crie a estrutura mínima necessária.
8. Configure a cena inicial.
9. Crie uma tela provisória de título.
10. Configure a exportação para navegador.
11. Execute o projeto localmente.
12. Teste a exportação web, se o ambiente permitir.
13. Crie a documentação mínima.
14. Registre os resultados.

Não comece a produzir dezenas de sprites nesta fase.

Crie apenas um placeholder ou uma arte provisória mínima para validar o pipeline.

Não implemente ainda classes, magias, missões complexas, multiplayer ou conteúdo extenso.

Ao finalizar, apresente:
- O que foi criado.
- Os arquivos modificados.
- Os comandos executados.
- Os testes realmente executados.
- O resultado da exportação web.
- Os problemas encontrados.
- As decisões pendentes.
- A próxima tarefa recomendada.

A prioridade é estabelecer uma base funcional, verificável, gratuita e organizada antes de adicionar complexidade.

**Regra final:** não confunda volume de código com progresso. O progresso é medido por funcionalidades integradas, testadas e utilizáveis no jogo.
