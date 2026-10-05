# Configuração

## Configurações

Clique no botão do minimapa ou digite `/atlasium` para abrir a janela de configurações.
Você também pode usar **Interface → AddOns → Atlasium**. As duas telas oferecem os mesmos controles.
As mudanças são aplicadas imediatamente. Fechar a janela ou clicar em Cancelar nas Opções de Interface
mantém as mudanças.

Escolha **English** ou **Português (Brasil)** em Geral. Inglês é o padrão.
A escolha altera as configurações, dicas, ajuda dos comandos e respostas do Atlasium sem recarregar a interface.
Os menus e o seletor de cores da Blizzard usam o idioma do cliente. Os logs de desenvolvimento continuam em inglês.

Arraste a barra de título para mover a janela. Feche com Escape ou pelo botão de fechar.
A posição da janela dura apenas durante a sessão atual.

| Configuração | Padrão | Como alterar |
| --- | --- | --- |
| Idioma | English | Escolha English ou Português (Brasil) em Geral. |
| Modo de depuração | Desativado | Digite `/atlasium debug` para alternar. Mostra um quadrado verde ou vermelho no canto superior esquerdo e define duas teclas do teclado numérico para auxiliar o desenvolvimento. |
| Botão do minimapa | Visível | Digite `/atlasium minimap button off` ou `/atlasium minimap button on`. |
| Posição do botão do minimapa | Borda inferior esquerda (225°) | Arraste o botão ou use o controle de 0–359°. |
| Zoom do minimapa pela roda do mouse | Ativado | Digite `/atlasium minimap zoom off` ou `/atlasium minimap zoom on`. |
| Terreno do minimapa (experimental) | Ativado | Digite `/atlasium minimap tiles off` ou `/atlasium minimap tiles on`. Desativar restaura o terreno da Blizzard. |
| Remoção da névoa | Ativada | Digite `/atlasium worldmap fog off` ou `/atlasium worldmap fog on`. |
| Arrastar e ampliar o mapa | Ativado | Digite `/atlasium worldmap zoom off` ou `/atlasium worldmap zoom on`. |
| Zoom máximo | 4 | Use o controle em Mapa-múndi: 1–16×, em passos de 0,25. |
| Zoom por movimento da roda | 1,25 | Use o controle em Mapa-múndi: 1,05–2, em passos de 0,05. |
| Cor de áreas inexploradas | Cinza (`r`, `g`, `b` 0.6, `a` 1) | Clique no botão da cor para escolher cor e opacidade. Cancelar restaura a cor anterior. |

As opções de ativar e desativar também têm caixas de seleção na janela de configurações.
O modo de depuração fica em Avançado. O terreno personalizado do minimapa continua marcado como experimental.

## Onde seus dados são salvos

O Atlasium armazena as configurações na variável salva `AtlasiumDB`.
O jogo a grava em `WTF\Account\<conta>\SavedVariables\Atlasium.lua` ao sair do jogo
ou recarregar a interface. Todas as personagens da conta compartilham essas configurações.

Novas versões adicionam valores padrão para novas opções e mantêm os valores que você já escolheu.

## Restaurar

Clique em **Restaurar padrões** na janela do Atlasium ou use o botão Padrões nas Opções de Interface
do Atlasium. Isso restaura a configuração, inclusive o idioma, e mantém o log salvo.

Para uma restauração completa, feche o jogo e exclua `Atlasium.lua` da pasta `SavedVariables` indicada acima.
O Atlasium usa os valores padrão na próxima inicialização.
