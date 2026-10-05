# Testes no jogo

Os testes automatizados não cobrem layout XML, frames reais nem texturas (veja [Testes](testing.md)).
Confira esses itens em um cliente 3.3.5a em execução.
`tools/wow-dev.ps1` executa Lua no cliente, mostra resultados, recarrega a interface,
tira capturas e abre ou fecha o mapa-múndi. Você ou o Claude Code pode verificar mudanças sem sair do editor.

## Preparação inicial

1. Vincule o add-on ao cliente para o jogo ler os arquivos do repositório:

   ```powershell
   New-Item -ItemType Junction -Path "<WoW>\Interface\AddOns\Atlasium" -Target "<repo>\Atlasium"
   ```

   Se o WoW estiver em `C:\Program Files`, execute em PowerShell como administrador.

2. Informe a pasta do cliente. Copie `.env.example` para `.env` na raiz e defina a pasta de `Wow.exe`:

   ```
   ATLASIUM_WOW_DIR=C:\Path\To\WoW
   ```

   O Git ignora `.env`. O script também aceita a variável de ambiente `ATLASIUM_WOW_DIR`
   ou `-WowDir <path>`. `-WowDir` tem prioridade sobre a variável, que tem prioridade sobre `.env`.

3. Use o modo janela ou janela em tela cheia e salve capturas em JPEG:
   `/console screenshotFormat jpeg`.
4. Digite `/atlasium debug`. A maioria dos modos do script precisa de depuração
   (veja [Modo de depuração](#debug-mode-map-marker-and-keys) e [Console](#dev-console)).
   A opção fica salva; faça isso uma vez.
5. Opcional: instale BugGrabber e BugSack para 3.3.5.
   Erros ficam em `WTF\Account\<ACCOUNT>\SavedVariables\!BugGrabber.lua` e podem ser lidos após recarregar.

## Log do Atlasium

O Atlasium registra erros e mensagens de depuração no chat e no log salvo.
Mensagens de depuração exigem esse modo ativado. Nesse modo, erros Lua do Atlasium também
aparecem como `Lua error: <message>`.
Os erros continuam indo à janela da Blizzard ou ao BugGrabber.
Com BugGrabber, a captura usa seus callbacks porque ele controla o tratador de erros.

Durante a execução, use `./tools/wow-dev.ps1 log` para ler as últimas 20 entradas, ou `log -Tail 50`.
Após uma sessão:

1. Digite `/reload` ou saia da personagem. O cliente grava as variáveis ao recarregar, sair ou fechar.
2. Abra `WTF\Account\<ACCOUNT>\SavedVariables\Atlasium.lua`.
3. Localize `log`. Guarda as últimas 200 entradas, da mais antiga para a mais recente.

## Inspecionar o estado

Em depuração, `AtlasiumDev` é o namespace do add-on (`ns`).
Use-o em `/run`, macros ou no console para ler o estado dos módulos:

```
/run print(AtlasiumDev.Dev.IsActive(), #AtlasiumDev.db.log)
/run local h = AtlasiumDev.Dev.GetHealth() print(h.modules, h.errors, h.lastError)
```

`AtlasiumDev` serve apenas para verificações.
O código do add-on não lê esse global (veja [Convenções](conventions.md#structure)).

O chat aceita no máximo 255 caracteres. `wow-dev.ps1 run` serve para código curto e retorna uma captura.
`wow-dev.ps1 eval` não tem esse limite de entrada e retorna texto.
Use `eval` com depuração ativada.

## Verificações da interface de configurações

O recurso adiciona entradas ao manifesto. Reinicie o cliente antes da primeira verificação.

Verificado no cliente 3.3.5a em 2026-10-04: as duas telas, textos em inglês e português,
limites de rolagem, callbacks, sincronização, prévia e cancelamento de cores, padrões,
cancelamento nas Opções de Interface, limites de zoom durante animação, incrementos da roda
e preferências após recarregar. O fechamento por janela especial nativa também passa.
A sessão registra zero erros Lua capturados. As preferências originais foram restauradas.

Arrastar fisicamente a barra de título, Escape, outras escalas de interface e mudanças em combate real
ainda precisam de verificações em campo. Os callbacks não substituem essas verificações.

1. Clique no botão do minimapa. As configurações devem abrir e o mapa-múndi deve continuar fechado.
2. Arraste a barra de título. A janela deve permanecer na tela. Feche com Escape.
3. Abra Interface → AddOns → Atlasium. Confira os mesmos controles nas duas telas.
4. Mude para Português (Brasil). Confira acentos, quebras, dicas e rolagem em escalas pequenas.
5. Alterne cada recurso. As mudanças devem ser imediatas.
   Oculte o botão e abra com `/atlasium`. Cancelar as Opções de Interface deve manter as mudanças.
6. Arraste o botão do minimapa. Os dois controles de posição devem atualizar.
7. Amplie o mapa. Reduza o zoom máximo durante a animação. Zoom e movimento devem respeitar os limites.
   Mude o multiplicador da roda e confira o próximo movimento.
8. Altere a cor e a opacidade com o mapa aberto. Cancele e confira a cor anterior.
   Repita e aceite a nova cor.
9. Abra as configurações em combate. Altere opções de mapa e depuração.
   Confira ações bloqueadas e erros Lua. As teclas de depuração devem atualizar após o combate.
10. Recarregue após selecionar português e mudar um recurso. As preferências devem permanecer.
11. Restaure padrões pelas duas telas. Inglês e recursos padrão devem voltar, mantendo o log.
    Marque como concluído apenas depois de observar no cliente.

## O que exige reiniciar

O cliente lê `.toc` apenas na inicialização. `/reload` lê Lua e XML novamente.

| Mudança | Necessário |
| --- | --- |
| Editar um `.lua` ou `.xml` existente | `/reload` |
| Alterar `Atlasium.toc` | Reiniciar |
| Adicionar um arquivo | Reiniciar |
| Alterar uma textura | Reiniciar (o cliente pode usar cache) |

`wow-dev.ps1` informa `RESTART_NEEDED` se uma dessas mudanças acontecer após iniciar o cliente.
Compara os horários do `.toc` e das texturas com o início do processo.
Para novos arquivos, salva a lista do add-on na primeira detecção do cliente,
em `%TEMP%\atlasium-wow-dev.json`.
Arquivos adicionados antes do primeiro `status` ou `reload` não são detectados como novos.

## Comandos

| Comando | Ação |
| --- | --- |
| `./tools/wow-dev.ps1 status` | Informa `RUNNING`, `RESTART_NEEDED` ou `NOT_RUNNING`. |
| `./tools/wow-dev.ps1 eval -Lua '<code>'` | Executa no console e retorna texto (veja [Console](#dev-console)). `-File <path>` lê de um arquivo. |
| `./tools/wow-dev.ps1 eval -Lua '<code>' -Until` | Repete até o primeiro retorno não ser `nil` nem `false`, ou até `-Timeout` (padrão 10 s). |
| `./tools/wow-dev.ps1 log` | Mostra as últimas entradas (`-Tail`, padrão 20). |
| `./tools/wow-dev.ps1 reload` | Confirma o mapa fechado e digita `/reload`. Com o console, aguarda uma nova carga e mostra a saúde. Sem console, aguarda `-LoadDelay` (padrão 8 s), captura e mostra `SCREENSHOT: <path>`. |
| `./tools/wow-dev.ps1 screenshot` | Tira captura por tecla, sem recarregar. |
| `./tools/wow-dev.ps1 run -Lua '<code>'` | Confirma o mapa fechado, digita `/run <code>`, captura e mostra `SCREENSHOT: <path>`. |
| `./tools/wow-dev.ps1 mapstate` | Lê o marcador e mostra `MAP_OPEN`, `MAP_CLOSED` ou `NO_MARKER`. |
| `./tools/wow-dev.ps1 mapopen` | Abre o mapa se estiver fechado e verifica novamente. |
| `./tools/wow-dev.ps1 mapclose` | Fecha o mapa se estiver aberto e verifica novamente. |

O script envia comandos e teclas por mensagens de janela.
O cliente permanece em segundo plano, permitindo usar o computador.
Comandos de chat precisam do mundo visível, sem menu nem chat aberto.

O marcador e a faixa do console são lidos por `PrintWindow`.
Uma captura leva 20–60 ms e não grava arquivos.
Funciona com outras janelas sobre o cliente, mas não com o cliente minimizado.
Sem marcador, os modos de mapa usam uma captura do WoW e mostram o caminho.

Códigos de saída:

| Código | Significado |
| --- | --- |
| 0 | ok |
| 2 | cliente não está em execução |
| 3 | reinício necessário |
| 4 | captura não encontrada |
| 5 | recarga não aconteceu |
| 6 | sem marcador ou faixa do console (depuração desligada, add-on ausente, interface oculta ou cliente minimizado) |
| 7 | mapa não abriu ou não fechou |
| 8 | mapa aberto: `run` ou `reload` não digitou |
| 9 | código Lua de `eval` falhou (erro mostrado na saída) |
| 10 | outro campo, como o chat, tem o teclado: `eval` não digitou |
| 11 | console não recebeu o teclado |
| 12 | sem resultado de `eval` no prazo |
| 13 | faixa falhou na soma de verificação |
| 14 | prazo de `eval -Until` terminou |

`reload` confirma a recarga pelo novo ID na faixa do console.
Sem console, verifica `Atlasium.lua` em `WTF\Account\<ACCOUNT>\SavedVariables`.
O cliente grava esse arquivo em cada recarga. Um arquivo anterior ao comando indica `NO_RELOAD`.

O script envia apenas textos iniciados por comando de barra.
Outros textos iriam ao chat público. Use PowerShell, não Git Bash:
Git Bash converte argumentos iniciados por `/` em caminhos.

## Modo de depuração: marcador e teclas

O mapa aberto recebe o teclado e ignora texto digitado.
Com `/atlasium debug`, `Atlasium/Dev.lua` fornece duas ferramentas:

- Um quadrado sólido de pelo menos 24 × 24 pixels no canto superior esquerdo, acima do mapa.
  Verde significa mapa aberto; vermelho, fechado.
- Duas teclas definidas com `SetOverrideBinding`. Não são salvas e são removidas ao desativar a depuração.
  Alterar M ou Print Screen não afeta o script.

| Tecla | Nome no WoW | Executa |
| --- | --- | --- |
| * do teclado numérico | `NUMPADMULTIPLY` | `TOGGLEWORLDMAP` |
| - do teclado numérico | `NUMPADMINUS` | `SCREENSHOT` |
| + do teclado numérico | `NUMPADPLUS` | Clique em `AtlasiumDevConsoleButton`: entrega o teclado ao console |

O script envia `WM_KEYDOWN` e `WM_KEYUP`. Essas teclas foram escolhidas porque:

- Não têm atalhos padrão em 3.3.5a.
- Enviam o mesmo código virtual independentemente do NumLock.
- Não são teclas estendidas, simplificando o scan code.
- O WoW não tem F13–F15 no Windows. Esses nomes são aliases do Mac para Print Screen, Scroll Lock e Pause.

O script não envia modificadores (Ctrl, Shift, Alt) com `PostMessage`, pois o cliente lê o teclado real.
Os atalhos não usam modificadores.

O mapa usa `OnKeyDown` para executar o resultado de `GetBindingFromClick`.
Um atalho de sobreposição pode não ser reconhecido ali. `Dev.lua` instala um hook e executa
o comando diretamente quando necessário. Atalhos de clique não funcionam com o mapa aberto;
o hook também entrega o teclado ao console com + do teclado numérico.

O cliente recusa mudanças de atalhos em combate.
Ativar ou desativar a depuração em combate aplica os atalhos após o combate.
O marcador não é protegido e muda imediatamente.

O script lê o centro do quadrado e aceita o estado quando pelo menos 90% dos pixels são
claramente verdes ou vermelhos. Usa pixels do cliente, independentemente do tamanho da janela.

Sem depuração, não há marcador nem teclas.
`mapstate`, `mapopen` e `mapclose` mostram `NO_MARKER`; `screenshot` não encontra arquivo.
`screenshot -ChatFallback` usa `/run Screenshot()`. Use apenas com o mapa fechado.

`run` e `reload` conferem o marcador antes de digitar.
Com o mapa aberto, retornam `MAP_OPEN` e código 8. Use `mapclose` primeiro.
Sem marcador, mostram `NO_MARKER` e digitam normalmente, pois não conseguem determinar o estado.
`reload -SkipMapCheck` ignora essa verificação.
Uma captura é adicionada a `Screenshots` apenas quando a captura de janela não tem marcador.

O script nunca envia Escape, que abriria o menu com o mapa fechado.

Status: script, marcador, teclas e testes estão implementados.
Os testes simulam a lógica do marcador e dos atalhos.
No jogo, o marcador aparece sobre o mapa, `mapstate` o lê e `OnKeyDown` recebe `NUMPADPLUS`.
Ainda não verificado no jogo: mensagens `NUMPADMULTIPLY` e `NUMPADMINUS`
para `mapopen`, `mapclose` e `screenshot`.

## Console de desenvolvimento

Em depuração, `Atlasium/DevConsole.lua` fornece o console usado por `wow-dev.ps1 eval`.
Não precisa de chat nem captura e funciona com o mapa aberto.
Uma execução completa leva cerca de um segundo.

Funcionamento de `eval`:

1. Captura a janela e lê o cabeçalho da faixa. Sem faixa, para com código 6.
   Se outro campo tiver o teclado, para sem digitar com código 10.
2. Pressiona + do teclado numérico. Um campo oculto recebe o teclado.
   Aguarda o sinal de foco por dois segundos; caso contrário, retorna 11.
3. Digita o código em hexadecimal e pressiona Enter.
   A codificação preserva `|` e texto fora de ASCII.
4. O console mostra `dev> <first line>` em cinza no chat e executa em `_G`, como `/run`.
   Primeiro tenta como expressão (`return <code>`), portanto `eval -Lua 'GetCVar("scriptErrors")'` retorna o valor.
5. O console coloca a saída na faixa. O script aguarda uma nova sequência,
   confere a soma de verificação e mostra o texto.

A saída inclui as linhas impressas sem códigos de cor, depois `=> ` e os retornos.
Strings aparecem entre aspas; tabelas mostram dois níveis e até 30 entradas por nível;
frames aparecem como `<Type Name>`.
Erros mostram `EVAL_ERROR:` e a mensagem (código 9).
Saídas acima de 4096 bytes são cortadas, com `(truncated at 4096 bytes)`.

Escape ou três segundos sem entrada fecham o console e liberam o teclado.

Exemplos:

```powershell
./tools/wow-dev.ps1 eval -Lua 'AtlasiumDev.Dev.GetHealth()'
./tools/wow-dev.ps1 eval -Lua 'WorldMapFrame:IsShown(), GetCurrentMapAreaID()'
./tools/wow-dev.ps1 eval -Lua 'WorldMapFrame:IsShown()' -Until -Timeout 5
./tools/wow-dev.ps1 eval -File probe.lua
```

Use `-Until` para estados que mudam ao longo de frames, como animação de zoom ou atualização de mapa.
Substitui uma espera fixa. Um erro conta como estado ainda não disponível.

A faixa fica à direita do marcador. Cada célula colorida guarda três bytes, um por canal de cor.
As cinco primeiras células são o cabeçalho:

| Célula | Conteúdo |
| --- | --- |
| 1 | bytes identificadores `Atl` |
| 2 | ID da carga: muda a cada carga e confirma `/reload` |
| 3 | sequência de dois bytes e flags: 1 foco do console, 2 foco de outro campo, 4 erro, 8 saída cortada |
| 4 | tamanho dos dados |
| 5 | soma de verificação |

As células têm quatro unidades de interface e 64 células por linha.
O script lê o centro porque as bordas são suavizadas.
Mantenha a geometria igual em `DevConsole.lua` e `tools/wow-dev.ps1`.

Com o console, `reload` aguarda um novo ID de carga em vez de um tempo fixo.
Depois executa `AtlasiumDev.Dev.GetHealth()` e mostra depuração, ID, módulos em `ns`,
tipo de captura (`errorCapture`: `handler`, `BugGrabber` ou `off`), quantidade de erros Lua
do Atlasium desde a carga e o último erro. Com `errorCapture = "off"`, `errors = 0` não comprova ausência de erros.

Status: console, script e testes estão implementados e verificados no jogo.
As cores chegam exatamente à captura; 3 KB com todos os valores de byte e texto UTF-8 passam na verificação.
Digitação e Enter funcionam com o mapa aberto e fechado, assim como o atalho +.
Uma execução leva 0,5–0,9 segundo.
`reload` aguarda o novo ID e mostra a saúde.
Com BugGrabber, erros de arquivos do Atlasium aparecem no relatório e no log.

## Verificar o alinhamento do terreno

Em depuração, `/atlasium minimap align on` e `off` controlam a comparação.
Os blocos aparecem sobre o terreno da Blizzard com meia opacidade, mantendo a máscara original.
Com escala e posição corretas, os mapas coincidem. A camada não intercepta o mouse.
Use em exteriores. Interiores, instâncias e cidades WMO usam o minimapa da Blizzard.
`/atlasium minimap align off` encerra a comparação.

Use + e - da Blizzard para selecionar os níveis durante a comparação.
O zoom atual e os CVars interno e externo devem corresponder para verificar o retorno ao terreno padrão.

Ao alterar o renderizador:

1. Compare os níveis 0–5 da Blizzard.
2. Ative o rastreamento de mestres de voo e confira um ponto do motor sobre o terreno.
3. Entre em caverna, Orgrimmar e instância. Confira o retorno do minimapa original.
4. Teste um minimapa quadrado e a opção de rotação.
5. Confira o desempenho ao correr e girar.
6. Confira andares de Dalaran, mar aberto e mudanças de zona.
7. Abra o mapa e recarregue a interface. Confira terreno e restauração das texturas.
8. Desative o terreno. Confira a restauração da máscara de outro add-on sem alterar sua textura de pontos.

Verificações em 2026-10-04 em Razormane Grounds:

- Automatizadas: 319 testes passam; luacheck não relata avisos nem erros.
- Comparações dos níveis 0–5 parecem consistentes.
- Desativar restaura o terreno e o estrato `BACKGROUND` originais.
- Abrir e fechar o mapa mantém o terreno personalizado funcionando.
- Rotação e formato quadrado simulado funcionam no zoom normal.
  Isso verifica o renderizador, não a integração com um add-on de minimapa quadrado.

A falha tinha duas causas: o mundo cobria a camada em `BACKGROUND`,
e a máscara transparente precisava ser reaplicada após carregar.
O renderizador agora eleva o minimapa de fundo para `LOW` enquanto desenha
e reaplica as trocas em `PLAYER_ENTERING_WORLD`.

Ainda pendente: ponto de rastreamento exclusivo do motor, retorno em caverna/cidade/instância,
desempenho ao correr e girar, andares de Dalaran, mar aberto, transições e um add-on quadrado real.
O rastreamento de mestre de voo não mostrou um ponto no local, portanto a verificação ficou incompleta.

A sessão final do BugGrabber contém dois erros de comandos diagnósticos:
`GetNumErrors` indisponível e um nome incorreto de tratador de comando.
Nenhum veio do Atlasium. A versão instalada usa `GetDB()` e `GetSessionId()` para ler os erros atuais.

Execute `wow-dev.ps1` com acesso à área de trabalho se a sandbox mostrar `NOT_RUNNING`
para um processo presente. Um identificador de janela zero na sandbox não prova que o cliente parou.

## Com Claude Code

A skill de projeto `ingame-check` executa os testes, `status` e `reload`.
Lê estado com `eval` e log com `log`. Usa capturas apenas para conferir a aparência.
Para o mapa, usa `mapopen`, `mapclose` e `mapstate`.
Com `RESTART_NEEDED` ou `NOT_RUNNING`, o Claude Code para e solicita reiniciar o cliente.
Aguarda sua confirmação de que o jogo voltou.

## Limites conhecidos

- Mensagens de carga podem sair do chat antes da captura porque outros add-ons imprimem depois.
  Para conferir algo em uma captura, mostre na tela, não no chat.
- Sem console, a espera após `/reload` é fixa. Aumente `-LoadDelay` se o cliente carregar lentamente.
- Alguns estados, como o mapa aberto, não sobrevivem à recarga. Prepare novamente antes da captura.
- Chat ou menu aberto impede os comandos. O script mostra `NO_RELOAD` ou `NO_SCREENSHOT`.
  Feche e tente novamente.
- Com o mapa aberto, apenas suas teclas funcionam. Comandos de chat são perdidos;
  `run` e `reload` não digitam. Use `mapclose` primeiro.
- Marcador e faixa não têm frame pai. Permanecem visíveis com mapa em tela cheia ou interface oculta por Alt-Z.
- Cada `eval` adiciona uma linha `dev>` ao chat; `-Until` adiciona uma por tentativa.
- Add-ons não leem arquivos durante a execução. Alterar Lua ainda exige `/reload`.
- O cliente não considera essas mensagens atividade. A personagem pode ficar ausente durante os testes.
