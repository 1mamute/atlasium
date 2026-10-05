# Uso

## Comandos

Digite os comandos no chat. `/atlasium` abre as configurações.
`/atlasium help`, ou um comando desconhecido, lista os comandos disponíveis.
As palavras dos comandos são iguais nos dois idiomas.

| Comando | Ação |
| --- | --- |
| `/atlasium` ou `/atlasium settings` | Abre as configurações, mesmo com o botão do minimapa oculto. |
| `/atlasium help` | Lista os comandos disponíveis. |
| `/atlasium version` | Mostra a versão instalada. |
| `/atlasium debug` | Ativa ou desativa a depuração. Nesse modo, um quadrado verde ou vermelho aparece no canto superior esquerdo (verde: mapa aberto). As teclas `*` e `-` do teclado numérico abrem o mapa e tiram uma captura. São ferramentas de desenvolvimento. |
| `/atlasium minimap` | Mostra as configurações do minimapa e o estado de cada opção. |
| `/atlasium minimap button on` | Mostra o botão do minimapa. |
| `/atlasium minimap button off` | Oculta o botão do minimapa. |
| `/atlasium minimap zoom on` | Ativa o zoom do minimapa pela roda do mouse. |
| `/atlasium minimap zoom off` | Desativa o zoom pela roda. O terreno personalizado continua ativado. |
| `/atlasium minimap tiles on` | Ativa o terreno personalizado do minimapa (experimental). |
| `/atlasium minimap tiles off` | Restaura o terreno da Blizzard. |
| `/atlasium minimap align on` ou `off` | Compara o terreno personalizado com o da Blizzard usando meia opacidade. Requer modo de depuração. |
| `/atlasium worldmap` | Mostra as configurações do mapa-múndi e o estado de cada opção. |
| `/atlasium worldmap zoom on` | Ativa o zoom e o movimento do mapa. |
| `/atlasium worldmap zoom off` | Desativa o zoom e o movimento para o mapa funcionar normalmente. |
| `/atlasium worldmap fog on` | Ativa a remoção da névoa. |
| `/atlasium worldmap fog off` | Desativa a remoção e restaura a névoa normal. |

Omita `on` ou `off` para consultar uma opção, por exemplo `/atlasium worldmap fog`.

## Botão do minimapa

O Atlasium coloca um botão redondo com um mapa em pergaminho na borda do minimapa.

- **Clique esquerdo** abre ou fecha as configurações do Atlasium. A tecla M continua abrindo o mapa-múndi.
- **Arraste** com o botão esquerdo para mover o botão pela borda do minimapa.
  A posição é mantida após recarregar a interface ou sair do jogo.
- **Passe o cursor** sobre o botão para ver a versão e essas ações na dica.
- Digite `/atlasium minimap button off` para ocultar o botão e `/atlasium minimap button on` para exibi-lo.

Se um add-on como o SexyMap deixar o minimapa quadrado, o botão acompanha a borda quadrada.

## Zoom do minimapa pela roda do mouse

- **Roda para cima** sobre o minimapa amplia um passo; **roda para baixo** reduz um passo.
  Funciona como os botões + e -, que continuam sincronizados.
- Nos limites mínimo e máximo, movimentos adicionais da roda não alteram o zoom.
- Um clique simples continua enviando um ping no minimapa.
- O jogo mantém um nível de zoom para interiores e outro para exteriores, como antes.
- Se outro add-on já usa a roda do mouse no minimapa, o Atlasium mantém esse comportamento.
- Use `/atlasium minimap zoom off` para desativar e `/atlasium minimap zoom on` para ativar.

## Terreno do minimapa

Este recurso é experimental. A renderização externa foi verificada no cliente.
O retorno ao terreno padrão em interiores, cidades e instâncias ainda precisa de verificações em campo.

- O Atlasium mostra o terreno sem iluminação nos seis níveis de zoom.
  O cliente desenha sua seta e os pontos sobre o terreno.
- O terreno acompanha o formato e a opção de rotação do minimapa.
- Interiores, instâncias, Orgrimmar, Thunder Bluff, Darnassus, Exodar e Ironforge usam o minimapa da Blizzard.
- `/atlasium minimap tiles off` restaura o minimapa da Blizzard.
  `/atlasium minimap zoom off` desativa a roda, mas mantém o terreno personalizado.
- Limite conhecido: uma máscara quadrada definida antes dos hooks de textura do Atlasium
  ainda não pode ser restaurada automaticamente.

## Remoção da névoa

Normalmente, o mapa-múndi esconde as áreas da zona que você ainda não explorou.
Com o Atlasium, toda a zona aparece. Áreas exploradas mantêm a aparência original;
áreas inexploradas ficam um pouco mais escuras.

- A remoção funciona em mapas de zonas. Mapas de continentes, cidades e masmorras não mudam.
- Use `/atlasium worldmap fog off` para restaurar a névoa e `/atlasium worldmap fog on` para removê-la.
  Se o mapa estiver aberto, a mudança é imediata. `/atlasium worldmap fog` consulta o estado.
- Sua escolha é mantida após recarregar a interface ou sair do jogo.

Use apenas um add-on de mapas por vez. Se a remoção da névoa do Mapster também estiver ativada,
o Atlasium escurece todas as áreas.

## Zoom e movimento do mapa

- **Roda do mouse** sobre o mapa-múndi amplia ou reduz ao redor do cursor, até 4×.
- **Arraste** com o botão esquerdo para mover o mapa ampliado. O movimento para nas bordas.
- **Clique** sem arrastar funciona como antes, por exemplo para abrir uma zona.
  O botão direito continua voltando um nível no mapa.
- Sua seta, os membros do grupo e os ícones de missões e cidades mantêm o tamanho durante o zoom.
- O zoom volta ao normal ao fechar o mapa ou mudar de zona, andar ou tamanho do mapa.
- Em combate, zoom e movimento continuam funcionando. As áreas azuis de missão ficam ocultas até o fim do combate.
- Use `/atlasium worldmap zoom off` para desativar e `/atlasium worldmap zoom on` para ativar.
  O Atlasium mantém sua escolha.

Os ícones do Questie acompanham o zoom e o movimento, mas ainda aumentam de tamanho com o zoom.

## Usar o mapa

Notas e integrações estão planejadas. Esta página explicará esses recursos quando forem implementados.
Veja [Recursos](features.md) para o status atual.
