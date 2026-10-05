# Instalação

> O Atlasium ainda não tem uma versão publicada. Por enquanto, instale pelo código-fonte. Alguns recursos ainda não estão disponíveis.

## Requisitos

- World of Warcraft **3.3.5a** (WotLK, interface 30300). Outras versões não são compatíveis.

## Instalar

1. Baixe ou clone o repositório do Atlasium.
2. Copie a pasta `Atlasium` (a que contém `Atlasium.toc`) para
   `<pasta do WoW>\Interface\AddOns\`.
3. Inicie o jogo. Na tela de personagens, clique em **AddOns** e confirme que o Atlasium está ativado.

O caminho final deve ser `<pasta do WoW>\Interface\AddOns\Atlasium\Atlasium.toc`.
Se houver uma pasta extra, como `Atlasium\Atlasium\Atlasium.toc`, o jogo não encontra o add-on.

## Verificar o funcionamento

Entre no jogo e digite:

```
/atlasium version
```

Uma mensagem como `Atlasium: v0.1.0` deve aparecer no chat.

## Atualizar

Substitua a pasta `Atlasium` em `Interface\AddOns` pela nova versão.
Suas configurações são mantidas (veja [Configuração](configuration.md)).

## Desinstalar

Exclua a pasta `Atlasium` de `Interface\AddOns`. Para remover também as configurações salvas,
exclua `AtlasiumDB` de `WTF\Account\<conta>\SavedVariables\Atlasium.lua` com o jogo fechado.
