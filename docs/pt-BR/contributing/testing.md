# Testes

Os testes ficam em `tests/*_spec.lua`. Execute `busted` na raiz do repositório.
Eles executam fora do jogo e simulam o cliente do WoW.

## Como os testes simulam o cliente

`tests/helper.lua` tem duas funções:

- `loadAddonFile(path, ns)` carrega um arquivo como o cliente, passando `"Atlasium"` e `ns`.
- `installWowStubs()` instala novas simulações dos globais do WoW e restaura as variáveis salvas.
  Retorna uma tabela `state` que registra as ações do código para o teste conferir.

Estas são as simulações:

| Simulação | Comportamento |
| --- | --- |
| `CreateFrame(type, name, parent)` | Retorna um frame simulado. Frames com nome também viram globais, como no cliente. |
| `Minimap` | Frame simulado de 140 × 140, centro em (940, 680), escala efetiva 1. |
| `Minimap_ZoomIn()`, `Minimap_ZoomOut()` | Adicionam `1` ou `-1` a `state.minimapZooms`. |
| `UIParent` | Tela de 1024 × 768. A escala efetiva é `state.uiScale` (padrão 1). |
| `GameTooltip`, `WorldMapFrame` | Widgets simulados que registram todas as chamadas. |
| `GetCursorPosition()` | Retorna `state.cursor.x` e `state.cursor.y`. |
| `ToggleFrame(frame)` | Adiciona o frame a `state.toggled`. |
| `SetOverrideBinding(owner, priority, key, command)`, `ClearOverrideBindings(owner)` | Gravam e limpam `state.bindings` (tecla para comando). `state.bindingOwner` guarda o último proprietário. |
| `GetBindingFromClick(key)`, `RunBinding(command)` | A primeira retorna `state.binds[key]`. A segunda adiciona o comando a `state.ran`. |
| `GetMinimapShape` | `nil`, como no cliente 3.3.5. Defina no teste para simular um add-on como o SexyMap. |
| `GetMapInfo()`, `GetNumMapOverlays()`, `GetMapOverlayInfo(i)` | Leem `state.map`: `name` é o nome do mapa e `overlays` lista as texturas das áreas exploradas. |
| `WorldMapDetailFrame` | Frame simulado. `CreateTexture` retorna uma textura com `Show`, `Hide` e `IsShown` reais e a adiciona a `WorldMapDetailFrame.textures`. |
| `hooksecurefunc(name, fn)` | Guarda `fn` em `state.hooks[name]`. Chame no teste para simular a função da Blizzard com hook. |
| `wipe(t)` | Limpa a tabela, como no cliente. |
| `DEFAULT_CHAT_FRAME`, `GetAddOnMetadata`, `SlashCmdList` | Mensagens vão para `state.messages`. A versão é `0.1.0`. |

A tabela `state` também tem `events` (eventos registrados), `scripts` (scripts definidos nos frames)
e `frames` (todos os frames criados).

Um frame simulado mantém estado real para `Show`, `Hide`, `IsShown`, `GetParent`, `GetName`,
`SetScript` e `GetScript`. `CreateTexture` retorna uma textura simulada.
Outros métodos em `PascalCase` são aceitos e registrados em `fake.calls[method]`.
Use `helper.lastCall(fake, method)` para obter os argumentos da última chamada.
Para mudar o retorno de um método, defina-o no frame, por exemplo
`frame.GetCenter = function() return 883, 623 end`.
Use `helper.newFake()` para criar outros widgets simulados.

Em `before_each`, chame `installWowStubs()` e crie um novo namespace.
Isso impede que o estado de um teste afete o próximo.
`installWowStubs()` também remove os globais dos frames nomeados do teste anterior.

## O que testar e como

| Código | Como testar |
| --- | --- |
| Funções puras (`Util`) | Chame diretamente. Não precisam de simulações. |
| Tratadores de eventos | Chame `ns.Core.OnEvent(nil, event, ...)` em vez de emitir eventos reais. |
| Comandos | Chame `SlashCmdList.ATLASIUM("...")` e confira `ns.db` e as mensagens registradas. |
| Scripts de frame (`OnClick`, `OnDragStart`) | Obtenha com `frame:GetScript(name)` e chame com os argumentos do cliente. |
| Layout XML, frames reais e texturas | Os testes automatizados não cobrem isso. Confira no jogo (veja [Testes no jogo](in-game-testing.md)). |

## Adicionar simulações

Simule apenas as funções chamadas pelo código em teste.
Adicione uma nova API a `installWowStubs()`, a `read_globals` em `.luacheckrc`
e aos globais de `tests/` em `.luacheckrc`.

Use `assert.near` para comparar valores de ponto flutuante, como posições calculadas com `math.cos`.
