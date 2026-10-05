# Recursos

O Atlasium está no início do desenvolvimento. Esta página mostra o que já funciona e o que está planejado.

| Recurso | Status |
| --- | --- |
| Comandos (`/atlasium version`, `/atlasium debug`, `/atlasium minimap button on` ou `off`, `/atlasium minimap zoom on` ou `off`, `/atlasium minimap tiles on` ou `off`, `/atlasium worldmap zoom on` ou `off`, `/atlasium worldmap fog on` ou `off`) | Disponível |
| Botão do minimapa | Disponível |
| Janela nativa de configurações e painel nas Opções de Interface | Disponível |
| Inglês e português brasileiro, selecionáveis nas configurações | Disponível |
| Zoom do minimapa pela roda do mouse | Disponível |
| Terreno do minimapa | Disponível (experimental) |
| Remoção da névoa | Disponível |
| Navegação fluida no mapa (arrastar e ampliar) | Disponível |
| Notas no mapa | Planejado |
| Integração com TomTom | Planejado |
| Integração com Questie | Planejado |
| Integração com o grupo | Planejado |

## Botão do minimapa

Um botão redondo na borda do minimapa. Clique para abrir ou fechar as configurações e arraste
para qualquer posição ao redor do minimapa. Veja [Uso](usage.md#minimap-button).

## Zoom do minimapa pela roda do mouse

Gire a roda do mouse sobre o minimapa para ampliar ou reduzir, um passo por movimento,
como os botões + e -. Veja [Uso](usage.md#minimap-wheel-zoom).

## Terreno do minimapa

O recurso mostra o terreno sem iluminação nos seis níveis de zoom do jogo.
O terreno acompanha o formato e a rotação do minimapa. Em interiores, instâncias e algumas cidades,
o minimapa da Blizzard é usado. A renderização externa foi verificada no cliente; algumas
verificações em campo ainda estão pendentes. Veja os controles e limites em [Uso](usage.md#minimap-tiles).

## Remoção da névoa

O mapa-múndi mostra todas as áreas de uma zona, inclusive as que você ainda não explorou.
As áreas inexploradas ficam um pouco mais escuras para facilitar a identificação.
Veja [Uso](usage.md#fog-clearing).

## Navegação fluida no mapa

Navegue pelo mapa-múndi como em um mapa online. Gire a roda do mouse para ampliar até 4×
ao redor do cursor e arraste com o botão esquerdo para mover o mapa ampliado.
Sua seta e os marcadores de missão mantêm o tamanho. Veja [Uso](usage.md#map-zoom-and-drag).

## Notas no mapa

Marque suas próprias notas: um inimigo raro, um vendedor ou uma rota de coleta, por exemplo.

## Integração com TomTom

Com o TomTom instalado, o Atlasium poderá definir pontos de destino e usar a seta do TomTom como guia.
O TomTom é opcional: o Atlasium funciona sem ele.

## Integração com Questie

Com o Questie instalado, o Atlasium poderá mostrar suas missões e objetivos no mapa.
O Questie é opcional: o Atlasium funciona sem ele.

## Integração com o grupo

O Atlasium poderá compartilhar pontos de destino, pings e notas com membros do grupo que também
tenham o add-on. Veja [Integração com o grupo](party.md).
