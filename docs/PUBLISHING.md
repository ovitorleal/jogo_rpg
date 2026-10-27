# Publicação (Fase 8)

O jogo é publicado como site estático no **GitHub Pages**, a partir do branch `gh-pages` deste repositório:
**https://ovitorleal.github.io/jogo_rpg/**

## Como publicar uma versão

1. Mesclar as mudanças no `main` e atualizar o repositório local (`git checkout main && git pull`).
2. Validar sem publicar:

   ```bash
   tools/publish/publish_web.sh
   ```

   O script roda os testes, exporta o preset "Web" para `exports/web`, gera `ENGINE_LICENSES.txt` (licença MIT do
   Godot e componentes de terceiros do motor) e confere os arquivos: `index.html`, `index.js`, `index.wasm`,
   `index.pck` e os worklets de áudio presentes e não vazios, nenhum `.import`, testes ou `exports/` dentro do pacote.
   Copia `LICENSE.txt` e `THIRD_PARTY_NOTICES.md`, grava `version.txt` (versão, commit, data) e `.nojekyll`.
3. Testar o build local (`web-build` em `.claude/launch.json`, porta 8060).
4. Publicar o mesmo build:

   ```bash
   tools/publish/publish_web.sh --deploy
   ```

   Só funciona num commit limpo do `main`. Substitui o conteúdo do branch `gh-pages` pelo build validado e faz o push.
   O Pages atualiza o site em alguns minutos; conferir o endereço e o `version.txt`.

Configuração do Pages (feita uma vez): Settings → Pages → Source "Deploy from a branch", branch `gh-pages`, pasta `/`.

## Requisitos técnicos do build

- Godot 4.7.2-stable, renderizador Compatibility (WebGL 2), WebAssembly.
- Sem threads (`variant/thread_support=false`): não exige os cabeçalhos COOP/COEP, por isso funciona no GitHub Pages.
- Tamanho publicado: cerca de 40 MB (o `index.wasm` do motor tem ~38 MB; o jogo em si, ~1 MB).
- Navegador desktop com WebGL 2 (Chrome, Edge, Firefox, Safari recentes). Celular não é alvo nesta versão.

## Limites da hospedagem

O GitHub Pages é gratuito para repositórios públicos e tem limites de tamanho do site, banda e uso definidos pelo
GitHub (conferir a versão atual em https://docs.github.com/pages/getting-started-with-github-pages/github-pages-limits
antes de cada publicação; este build tem ~40 MB). Esses limites podem mudar e a hospedagem gratuita **não é garantida
como ilimitada nem permanente**. Se o site ficar fora do ar, o build pode ser
servido por qualquer hospedagem estática (os arquivos de `exports/web` bastam).

## Salvamento no navegador

- O jogo guarda o progresso no armazenamento local do navegador (`user://`, que o Godot mapeia para o IndexedDB).
- O salvamento é **local ao navegador, ao perfil e ao endereço do site**: não sincroniza entre aparelhos nem entre
  navegadores, e o jogo publicado não vê o salvamento do build local (`localhost`) nem o contrário.
- Limpar os dados do site ou do navegador (ou usar janela anônima) **apaga o progresso**.
- A tela de título avisa quando o armazenamento não é permanente.

## Limitações conhecidas da versão 0.8.0

- Conteúdo: uma aventura de demonstração ("A Garra-Rubra"), três mapas, um chefe e encontros de viagem.
- Grupo de um personagem; companheiros controlados pela IA ainda não existem (Inspiração de Bardo, por exemplo, não
  tem outro aliado para receber).
- Testes contra a morte não existem: cair a 0 PV encerra o combate em derrota e o jogo volta ao último salvamento.
- Reações e ações bônus de monstros ainda não existem (Fuga Ágil e Redirecionar Ataque do Garra-Rubra).
- Magias de exploração, invocação, muralhas e transformação ainda não existem; várias características de classe de
  exploração estão registradas sem efeito (lista em `RULES_POLICY.md`).
- Só o Lobo tem arte própria na Forma Selvagem; efeitos visuais de área são simples.
- Sem áudio.
- Nome do jogo provisório ("PROJECT_NAME").
