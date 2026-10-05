# Arquitetura

Esta página mostra a organização do código do Atlasium.

## Estrutura de pastas

```
Atlasium/          the add-on; put this folder in Interface/AddOns
  Atlasium.toc     manifest (Interface 30300, saved variable AtlasiumDB)
  Util.lua         pure helper functions that do not call the WoW API
  Localization.lua  English and Brazilian Portuguese strings and live language selection
  Core.lua         event handling, saved-variable setup, the /atlasium command
  Log.lua          error and debug messages, in chat and in the saved log
  MinimapButton.lua  the minimap button and its position math
  Data/MinimapTileData.lua  minimap tile names and zone bounds (generated, do not edit)
  MinimapTiles.lua  terrain at every minimap zoom: tile math, texture swaps and the tile layer
  MinimapZoom.lua  mouse wheel zoom on the minimap
  Data/Overlays.lua  the world map overlays of all zones (generated, do not edit)
  FogClear.lua     fog clearing on the world map, and its tile math
  MapNavigation.lua  zoom and drag on the world map
  Dev.lua          debug-mode aids for in-game checks: the map marker, fixed keys, AtlasiumDev
  DevConsole.lua   debug-mode dev console: runs Lua from tools/wow-dev.ps1, shows the result
  Settings.lua     shared validation and feature setters for configuration edits
  SettingsUI.lua   shared controls in the native window and Interface Options panel
tests/             busted specs and WoW stubs (not part of the add-on)
tools/             developer scripts, for example the generator of Data/MinimapTileData.lua
docs/              documentation
```

## Namespace compartilhado

Cada arquivo começa com esta linha:

```lua
local ADDON_NAME, ns = ...
```

O jogo passa dois valores para cada arquivo do `.toc`: o nome do add-on e uma tabela compartilhada.
Cada módulo se registra nessa tabela (`ns.Util`, `ns.Core`), sem precisar de globais.
Os únicos globais são `AtlasiumDB`, o comando, os nomes de frame com prefixo `Atlasium`
e, apenas em depuração, `AtlasiumDev` (veja [Convenções](conventions.md#structure)).

## Ordem de carregamento

O jogo carrega os arquivos na ordem do `.toc`. Um arquivo só pode usar módulos que aparecem antes dele.
`Util.lua` vem primeiro porque `Core.lua` o usa.
`MinimapButton.lua` vem depois de `Core.lua` e registra `PLAYER_LOGIN` com `Core.RegisterEvent` ao carregar.
`Log.lua` vem logo após `Core.lua`, para todos os recursos poderem registrar mensagens.
`Data/Overlays.lua` vem antes de `FogClear.lua`, que lê `ns.Overlays`.
`Data/MinimapTileData.lua` e `MinimapTiles.lua` vêm antes de `MinimapZoom.lua`,
pois o tratador da roda chama `ns.MinimapTiles`.

Código que precisa de configurações salvas ou de outros add-ons aguarda um evento.
O botão do minimapa é criado em `PLAYER_LOGIN`. Nesse momento, `AtlasiumDB` está pronto
e os add-ons que definem `GetMinimapShape` já carregaram.

## Configurações e localização

`Localization.lua` carrega antes de `Core.lua`. Resolve os textos no momento do uso a partir de `ns.db.language`.
Inglês é o idioma padrão e a alternativa para textos ausentes. Mantenha comandos e logs em inglês.

`Settings.lua` carrega depois dos módulos de recursos.
`Get`, `Set` e `ResetDefaults` compartilham o comportamento entre comandos e controles da interface.
Mudanças inválidas mantêm o estado anterior. Novos limites numéricos valem para mudanças;
carregar preferências existentes não as reescreve.

`SettingsUI.lua` registra um painel nas Opções de Interface em `PLAYER_LOGIN`.
Cria a janela independente no primeiro uso. As duas telas usam o mesmo construtor de conteúdo.
Atualizar uma tela suprime callbacks dos controles, para a exibição não alterar opções.
Mudanças são imediatas e permanecem ao fechar. Restaurar padrões usa os setters dos recursos e preserva o log.

O botão do minimapa resolve `ns.SettingsUI` ao clicar, após carregar todos os arquivos.
Arrastar o botão atualiza os controles de posição.
Alterar o idioma atualiza as duas telas e as dicas visíveis.

## Hooks no código da Blizzard

Use `hooksecurefunc` para executar código depois de uma função da Blizzard.
Não substitua funções nem globais da API. Isso afeta outros add-ons e pode contaminar código protegido.
`FogClear.lua` instala um hook em `WorldMapFrame_Update` ao carregar.
FrameXML carrega antes dos add-ons, portanto a função existe.
O mapa abre após o login, mas o hook ainda verifica `ns.db`.

## Dados de remoção da névoa

`Data/Overlays.lua` vem de `WorldMapOverlay.dbc` e `WorldMapArea.dbc` do cliente 3.3.5a (build 12340).
O cliente não tem API para as sobreposições inexploradas, por isso o add-on inclui essa tabela.
As chaves são os nomes de mapa de `GetMapInfo()`.
Os nomes de sobreposição preservam maiúsculas e minúsculas dos dados do jogo;
compare sem considerar a caixa com `FogClear.OverlayKey`.
Os dados não mudam. Não edite o arquivo manualmente.
`tests/overlays_spec.lua` verifica sua estrutura.

## Terreno do minimapa

`MinimapTiles.lua` desenha o terreno sob o minimapa da Blizzard em cada nível de zoom.
Uma máscara transparente oculta o terreno original. O cliente continua desenhando a seta e os pontos.
A renderização externa foi verificada no cliente.

### Dados

`Data/MinimapTileData.lua` vem de `md5translate.trs`, `Map.dbc`, `WorldMapArea.dbc` e `DungeonMap.dbc`.
`tools/gen_minimap_tiles.py` gera o arquivo (veja [Desenvolvimento](development.md#generate-the-minimap-tile-data)).
Não edite manualmente.

- `tiles[folder]["x_y"]` contém o nome de `Textures\Minimap\<md5>.blp`.
  Apenas as quatro pastas de continentes estão nos dados. Uma chave ausente indica mar aberto.
- `zones[mapName]` contém a pasta do terreno e os limites da zona em jardas do mundo.
  As chaves são os nomes de `GetMapInfo()`, como em `ns.Overlays`.
  Mapas de continentes não entram: eles mostram zonas de outros continentes,
  e uma posição pode apontar para a pasta errada.
- `floors[mapName][level]` contém os limites de um andar de masmorra para uma zona
  que o mapa mostra apenas como andares, como Dalaran.

`tests/minimap_tile_data_spec.lua` verifica a estrutura e alguns valores conhecidos.

### Cálculos

A primeira parte do arquivo contém funções puras:

1. `ZoneToWorld` converte `GetPlayerMapPosition` para jardas do mundo.
   Esquerda e direita são o eixo Y; cima e baixo são o eixo X.
2. `WorldToTile` converte jardas em unidades de blocos. Cada bloco mede 533,33 jardas.
   A coluna aumenta para leste e a linha para sul.
3. `GetDiameter` usa os diâmetros externos dos níveis 0–5 da Blizzard:
   466,67; 400; 333,33; 266,67; 200 e 133,33 jardas.
4. `BuildSegments` cobre o formato do minimapa com faixas horizontais de duas unidades,
   sobrepostas em 0,35 unidade. Divide cada faixa nas bordas de blocos.
   Cada parte usa os oito argumentos de `SetTexCoord`, incluindo mapas girados.
   `GetRowExtent` calcula a largura pelos quadrantes de `Util.GetRoundQuarters`,
   usando a mesma regra do botão do minimapa.

### Camada

A segunda parte conecta os cálculos à API:

- A camada é filha de `MinimapCluster`, ancorada a `Minimap`, no nível do minimapa menos um.
  Usa o mesmo estrato. Não recebe o mouse nem desenha outra seta do jogador.
- Em 3.3.5a, o mundo cobre texturas comuns no estrato `BACKGROUND`.
  O minimapa do motor ainda aparece ali. Ao desenhar o terreno, o Atlasium eleva um minimapa
  de fundo e sua camada para `LOW`. Desativar ou retornar ao terreno original restaura o estrato.
  Um hook seguro preserva mudanças posteriores de outros add-ons.
- `SetMaskTexture` usa `Interface\WORLDMAP\Silithus\pixelfix1` para ocultar o terreno da Blizzard.
- Um hook seguro memoriza máscaras de outros add-ons.
  Enquanto a máscara está transparente, o Atlasium reaplica a transparência.
  Ao parar, restaura o caminho memorizado. O padrão é `Textures\MinimapMask`.
  As texturas dos pontos não mudam. Máscaras definidas antes dos hooks são um limite conhecido.
- `PLAYER_ENTERING_WORLD` reaplica texturas transparentes após carregar o mundo.
  O motor pode restaurá-las sem chamar os setters Lua.
  Verificar apenas mudanças de estado não mantém o terreno oculto após login ou recarga.
- Um script `OnUpdate` executa enquanto o recurso está ativado, inclusive usando o terreno original.
  Até 30 vezes por segundo, lê posição, direção, formato, tamanho e zoom.
  Desenha novamente só quando a visão muda. Não aplica iluminação nem tonalidade de sombra.
- A posição vem do mapa-múndi atual. Com o mapa fechado e sem posição,
  chama `SetMapToCurrentZone()` no máximo uma vez por segundo.
  Com o mapa aberto, mantém a última posição.
- As texturas usam um pool. `SetTexture` só é chamado quando o bloco muda.
- Em instâncias, interiores, cidades WMO ou sem posição, a camada fica oculta.
  Os nomes de mapas WMO são `Ogrimmar`, `ThunderBluff`, `Darnassis`, `TheExodar` e `Ironforge`.
  `IsIndoorZoom` compara os CVars de zoom interno e externo com o zoom atual.
- O alinhamento de depuração mostra os blocos acima do minimapa com meia opacidade e mantém a máscara da Blizzard.
  `/atlasium minimap align on|off` controla isso no nível de zoom atual.

`MinimapZoom.lua` envia cada movimento da roda pelos botões da Blizzard, que impõem os seis níveis nativos.
O renderizador mantém os tratadores originais dos botões. `MINIMAP_UPDATE_ZOOM` redesenha imediatamente.
Mudanças de zona verificam o retorno ao terreno original após atualizar o mapa atual.

A configuração fica em `minimapTiles`: `enabled`.
`/atlasium minimap tiles off` restaura a máscara da Blizzard.
O zoom pela roda tem sua própria opção; desativá-lo mantém o terreno personalizado.

## Navegação do mapa

`MapNavigation.lua` cria seus frames na primeira abertura do mapa.
Move `WorldMapDetailFrame`, `WorldMapBlobFrame`, `WorldMapButton` e `WorldMapPOIFrame` para esta árvore:

```
WorldMapFrame
   viewport     ScrollFrame where the map was; it clips the map
     scrollChild  scrolled by the drag
       zoomFrame  scaled by the zoom; holds the Blizzard map frames
   overlay      unscaled, over the viewport; holds the zone name label
```

Partes principais:

1. **Hooks de layout.** Hooks em `SetPoint` e `SetScale` movem o viewport quando a Blizzard muda o tamanho do mapa.
   Frames ancorados ao frame de detalhes passam a usar o viewport.
2. **Zoom e movimento.** A roda define o zoom de destino e `OnUpdate` aproxima suavemente.
   O ponto sob o cursor permanece fixo. Arrastar com o botão esquerdo move o scroll child.
   Arrastar não conta como clique, portanto não abre uma zona.
3. **Ícones.** Recebem escala `1/zoom` e deslocamentos multiplicados por `zoom`.
   Mantêm tamanho e posição. Isso inclui unidades, pontos de interesse, POIs de missão
   e o botão de troca de missão concluída.
   `ResolveRaw` distingue valores originais dos nossos, evitando acumular mudanças.
4. **Área de missão.** O frame fixa a área na tela ao desenhar.
   Após cada zoom ou movimento, o módulo limpa e redesenha a área selecionada.
5. **Combate.** O frame da área pode ser protegido e tornar seus pais protegidos durante combate.
   Ele sai da árvore antes do combate e volta depois.
   Um ScrollFrame desenha na ordem de entrada.
   `WorldMapButton` e `WorldMapPOIFrame` entram novamente após a área para os ícones não ficarem cobertos.

O zoom volta a 1× ao fechar o mapa ou alterar mapa, andar ou layout.
Em 1×, a aparência é a mesma de um mapa sem Atlasium.

## Log

`Log.lua` registra erros e mensagens de depuração.
`Log.Error(...)` e `Log.Debug(...)` unem os argumentos com espaços, como `print`.
Cada mensagem vai ao chat com `[ERROR]` ou `[DEBUG]` e a `AtlasiumDB.log` com o horário,
por exemplo `"2026-10-04 12:34:56 [ERROR] msg"`.

- Erros são sempre registrados.
- Mensagens de depuração só são registradas com esse modo ativado (`/atlasium debug`).
- O log guarda as 200 entradas mais recentes (`Log.MAX_ENTRIES`). Exceder o limite remove a mais antiga.
- Antes de `ADDON_LOADED`, não há variáveis salvas.
  Erros vão apenas ao chat; mensagens de depuração são descartadas.

Em depuração, o log também captura erros Lua.
`Log.SetErrorCapture` instala um tratador antes do atual com `seterrorhandler`:

- Erros de `AddOns\Atlasium\` vão para `Log.Error` como `Lua error: <message>`.
  `Log.errorCount` e `Log.lastError` contam e guardam o último erro para o relatório.
- Todos os erros, inclusive de outros add-ons, seguem para o tratador anterior.
  A janela da Blizzard ou o BugGrabber continua mostrando os erros.
- A captura começa em `ADDON_LOADED` se a depuração estiver salva como ativada.
  Isso inclui erros em `PLAYER_LOGIN`. `Dev.Update` acompanha mudanças de modo.
- Desativar restaura o tratador anterior, se nenhum outro add-on o trocou depois.
  Caso contrário, o tratador do Atlasium fica na cadeia e só encaminha erros.
- BugGrabber torna `seterrorhandler` inoperante. A captura usa os callbacks
  `BugGrabber_BugGrabbed` e `BugGrabber_BugGrabbedAgain`.
  O caminho vem como `Atlasium-<version>\<file>`; `Log.IsAddonError` aceita esse formato.
  Apenas a primeira linha é lida, pois a pilha pode citar outros add-ons.
  Os callbacks dependem de CallbackHandler-1.0, que pode carregar depois do Atlasium.
  A captura tenta novamente em `PLAYER_LOGIN`. Erros anteriores vão apenas ao BugGrabber.
- Se outro add-on bloquear `seterrorhandler` e não houver callbacks do BugGrabber em `PLAYER_LOGIN`,
  a captura permanece desativada e registra uma mensagem de depuração uma vez.
- `Log.GetErrorCapture()` retorna `handler`, `BugGrabber` ou `off`.
  O relatório mostra esse estado: `errors = 0` com captura desligada não indica ausência de erros.

Sem depuração, os erros Lua vão apenas ao tratador da Blizzard.

## Manter o código testável

Separe o código em dois tipos:

- **Lógica pura** recebe valores comuns e retorna valores comuns, sem chamar a API do WoW.
  Veja `Util.lua`. Os testes chamam diretamente.
- **Integração com a API** cria frames, registra eventos e escreve no chat.
  Mantenha pequena. Veja `Core.lua`. Os testes usam as simulações de `tests/helper.lua`.

Quanto menor a integração com a API, menos verificações manuais são necessárias no jogo.

## Módulos planejados

Notas, integração com TomTom, integração com Questie e sincronização de grupo
(veja o [README do projeto](../home.md)) terão arquivos próprios em `Atlasium/` e entradas no `.toc`.
Integrações são opcionais. Confira se o outro add-on carregou antes de chamar,
para o Atlasium continuar funcionando sem ele.
