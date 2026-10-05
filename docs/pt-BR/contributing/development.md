# Desenvolvimento

Esta página explica como preparar o ambiente, executar as verificações e adicionar código.

## 1. Instalar o add-on no jogo

Vincule a pasta `Atlasium` à pasta de add-ons do WoW.
Assim, cada mudança aparece no jogo sem copiar os arquivos.
Use PowerShell como administrador ou ative o Modo de Desenvolvedor do Windows.

```powershell
New-Item -ItemType SymbolicLink `
  -Path "<WoW folder>\Interface\AddOns\Atlasium" `
  -Target "<path to this repo>\Atlasium"
```

Substitua `<WoW folder>` pela pasta do cliente 3.3.5a e `<path to this repo>` pela pasta do repositório.
Após cada mudança, digite `/reload` no jogo. Use `/atlasium version` para confirmar que o add-on carregou.

## 2. Instalar as ferramentas

Você precisa destas ferramentas:

- Lua 5.1, a versão usada pelo cliente.
- LuaRocks.
- [busted](https://lunarmodules.github.io/busted/) para testes.
- [luacheck](https://github.com/lunarmodules/luacheck) para análise estática.

Instale busted e luacheck com LuaRocks:

```
luarocks install busted
luarocks install luacheck
```

## 3. Executar as verificações

Na raiz do repositório:

```
luacheck Atlasium tests    # lint
busted                     # run all specs (settings are in .busted)
```

A integração contínua executa os mesmos dois comandos a cada envio.
Confirme que eles passam no seu computador antes de enviar mudanças.

## Adicionar um arquivo

1. Crie `Atlasium/Foo.lua` e comece com `local _, ns = ...`.
2. Adicione o arquivo a `Atlasium/Atlasium.toc`, depois de suas dependências.
3. Adicione cada nova função da API do WoW a `read_globals` em `.luacheckrc`.
   Se os testes precisarem da função, adicione uma simulação em `tests/helper.lua`.
4. Crie `tests/foo_spec.lua`.

Antes de usar uma função, evento ou método de widget do WoW, confirme que existe em 3.3.5a.
Muitas APIs modernas não existem nesse cliente.

## Gerar os dados do terreno do minimapa

`Atlasium/Data/MinimapTileData.lua` vem dos arquivos do jogo.
Os dados não mudam. Execute este procedimento apenas quando alterar o gerador.
A integração contínua não executa o gerador.

1. Instale Python 3 e o leitor de MPQ `mpyq`:

   ```
   pip install mpyq
   ```

2. Na raiz do repositório, execute o gerador com a pasta do cliente 3.3.5a:

   ```
   python tools/gen_minimap_tiles.py "<WoW folder>"
   ```

   Sem a pasta, o script lê `ATLASIUM_WOW_DIR` de `.env` na raiz do repositório.

3. O script mostra o MPQ de origem de cada arquivo e as quantidades de zonas e blocos.
   Ele grava o arquivo de dados novamente.
4. Execute `busted tests/minimap_tile_data_spec.lua` para conferir o resultado.

Próximas páginas: [Testes](testing.md) e [Convenções](conventions.md).
