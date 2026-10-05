# Contribuição

Esta seção é para desenvolvedores. Ela explica como preparar, testar e alterar o Atlasium.
Para conhecer os recursos para jogadores, leia o [README do projeto](../home.md).

## Ordem de leitura

1. [Desenvolvimento](development.md): instale as ferramentas, vincule o add-on ao jogo e execute as verificações.
2. [Arquitetura](architecture.md): conheça a organização do código e as decisões principais.
3. [Testes](testing.md): entenda as simulações do cliente e onde testar cada comportamento.
4. [Testes no jogo](in-game-testing.md): verifique uma mudança no cliente real.
5. [Convenções](conventions.md): regras de código para Lua no cliente 3.3.5a.
6. [Versões](releases.md): números de versão, mensagens de commit, tags e pacotes de publicação.

## Antes de enviar uma mudança

1. Execute `luacheck Atlasium tests` e corrija todos os avisos.
2. Execute `busted` e confirme que todos os testes passam.
3. Crie um arquivo de testes correspondente para cada novo arquivo.
4. Confira se cada função do WoW usada existe na versão 3.3.5a.
5. Se mudar algo visível aos jogadores, atualize os documentos em `docs/`.

A integração contínua executa as mesmas verificações a cada envio.
