# Convenções

Estas são as regras do código do Atlasium. O luacheck aplica as regras que consegue verificar.

## Estrutura

- **Sem globais.** Use a tabela compartilhada `ns`. Os globais permitidos são `AtlasiumDB`,
  `SLASH_ATLASIUM1` e `SlashCmdList["ATLASIUM"]`.
- **`AtlasiumDev`** é a exceção. Em modo de depuração, `Dev.lua` define `AtlasiumDev = ns`.
  Isso permite ler o estado com `/run` e o console (veja [Testes no jogo](in-game-testing.md#inspect-state)).
  Serve apenas para verificações. O código do add-on nunca lê esse global, e ele não é uma API pública.
  Uma API para Questie, TomTom ou recursos de grupo precisa de um projeto separado.
- **Nomes de frames** também criam globais. Dê um nome apenas quando o cliente ou outro add-on precisar dele.
  Use o prefixo `Atlasium`, por exemplo `AtlasiumMinimapButton`.
  Escape fecha uma janela apenas se o nome estiver em `UISpecialFrames`.
  Coletores de botões do minimapa encontram botões pelo nome, e XML `$parent` precisa de um nome.
  Guarde o frame em um campo do módulo (`MinimapButton.frame`). Use esse campo no código, não o global.
- **Add-ons opcionais** (TomTom, Questie): confira se o global ou a API existe antes de chamar.
  Mantenha cada integração em seu próprio arquivo para o núcleo funcionar sem ela.

## Interface

Deixe a interface o mais parecida possível com uma janela nativa.
O add-on deve parecer um recurso do cliente original.

Use o WoW 3.3.5a como referência visual. Use modelos, texturas, fontes, controles e comportamento da Blizzard.
Mantenha os textos em inglês e português legíveis em escalas pequenas.
O Atlasium usa o idioma selecionado no add-on. As janelas da Blizzard usam o idioma do cliente.

## Comportamento no jogo

- **Variáveis salvas:** mescle os valores padrão em `ADDON_LOADED` com `Util.CopyDefaults`.
  Não sobrescreva os dados do usuário nem leia `AtlasiumDB` antes desse evento.
- **Eventos:** registre com `Core.RegisterEvent`. Remova os registros que não são mais necessários.
  Os tratadores executam na ordem de registro, que segue a ordem dos arquivos.
  Por exemplo, `MinimapButton.lua` registra `PLAYER_LOGIN` antes de `Dev.lua`.
- **Mensagens:** use `Log.Error` para problemas e `Log.Debug` para informações úteis ao desenvolvimento.
  Use `Core.Print` apenas para respostas ao jogador, como comandos.
  Não confira `ns.db.debug` antes de `Log.Debug`; a função já faz isso.
- **Desempenho:** em código frequente, mantenha as funções da API em variáveis locais
  (`local GetTime = GetTime`). Não crie tabelas ou closures em `OnUpdate`.
- **Mensagens de add-on** (grupo): use `SendAddonMessage` com um prefixo curto e exclusivo,
  de no máximo 16 bytes em 3.3.5a. Mantenha cada mensagem abaixo de 255 bytes.
  Valide todos os dados recebidos de outros jogadores.

## Add-ons de referência

- Carbonite, Mapster, Questie-335 e TomTom mostram como o cliente 3.3.5a funciona.
  Leia para entender o comportamento e escreva seu próprio código.
  Não copie: a maior parte não usa a licença MIT.
- **Não confie na tabela de formatos do minimapa do Questie-335.** A cópia de LibDBIcon-1.0
  em `Compat/Libs/LibDBIcon-1.0/` (Rev 15) tem uma tabela `minimapShapes` incorreta.
  Ela troca vários formatos `CORNER-*`, `SIDE-*` e `TRICORNER-*`.
  Use a regra de `MinimapButton.lua`.

## Linguagem e estilo

- **Apenas Lua 5.1.** Não use `goto`, operadores de bits ou `//`. Use a biblioteca `bit`.
- **Formatação:** quatro espaços de recuo e até 120 colunas.
- **Nomes:** `PascalCase` para funções de módulo e `camelCase` para variáveis locais.
- **Comentários:** adicione um comentário `---` curto para cada função pública.

## Versões

- Aumente `## Version` no `.toc` a cada versão publicada.
