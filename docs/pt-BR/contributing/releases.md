# Versionamento e publicação

O Atlasium segue [Semantic Versioning 2.0.0](https://semver.org/)
e [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

## Números de versão

`Atlasium/Atlasium.toc` é a fonte da versão. Use `MAJOR.MINOR.PATCH`, sem o prefixo `v`.
As tags do Git usam a mesma versão com o prefixo `v`, por exemplo `v1.0.0`.

O contrato de compatibilidade cobre comandos documentados, configurações, dados salvos e clientes do jogo compatíveis.
As funções Lua internas em `ns` não são uma API pública.

- Aumente PATCH para correções compatíveis, por exemplo de `1.0.0` para `1.0.1`.
- Aumente MINOR para recursos compatíveis, por exemplo de `1.0.1` para `1.1.0`.
- Aumente MAJOR para mudanças incompatíveis, por exemplo de `1.1.0` para `2.0.0`.
- Use um sufixo de pré-lançamento para versões de teste, por exemplo `1.1.0-rc.1`.

Documente mudanças incompatíveis e instruções de migração em `CHANGELOG.md`. Nunca mova uma tag publicada ou substitua seu pacote.
Recursos planejados não impedem uma versão estável dos recursos disponíveis.
Recursos experimentais mantêm esse status nas versões estáveis.

## Mensagens de commit

Use este formato para novos commits e títulos de pull requests:

```text
type(optional-scope): short description
```

Use `feat` para novos recursos e `fix` para correções.
Os outros tipos são `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore` e `revert`.
Use `!` antes dos dois-pontos ou um rodapé `BREAKING CHANGE:` para mudanças incompatíveis.

```text
feat(map): add map notes
fix(minimap): restore terrain after loading
feat(settings)!: replace a saved setting
```

`feat` normalmente exige uma versão MINOR. `fix` normalmente exige uma versão PATCH.
Uma mudança incompatível exige uma versão MAJOR, independentemente do tipo.
Os outros tipos, por si só, não exigem uma versão para jogadores.
O mantenedor escolhe a próxima versão com base em todas as mudanças desde a tag anterior.

A integração contínua verifica os títulos das pull requests. O squash merge usa esse título como assunto do commit.
O histórico existente permanece igual. Antes de um commit direto, verifique seu assunto:

```text
python tools/check_commit.py "chore(release): prepare v1.0.0"
```

## Publicar uma versão

1. Integre as mudanças de publicação em `main` com um título no formato Conventional Commits.
2. Antes da integração, atualize a versão no TOC e adicione uma seção correspondente em `CHANGELOG.md`.
3. Execute `luacheck Atlasium tests`, `busted` e `python -m unittest discover -s tests -p 'test_*.py'`.
4. Execute `python tools/package_release.py --tag v1.0.0` com a versão escolhida.
5. Confira `.build/release/Atlasium-v1.0.0.zip`.
6. Crie e envie a tag anotada a partir do commit de publicação:

   ```text
   git tag -a v1.0.0 -m "Atlasium v1.0.0"
   git push origin v1.0.0
   ```

O workflow Release executa as verificações novamente. Ele confirma que a tag corresponde à versão no TOC.
Ele publica o ZIP, uma soma SHA-256 e a seção correspondente do histórico no GitHub.
Tags com sufixo de pré-lançamento geram prereleases no GitHub.
Se um workflow falhar, corrija a causa e execute-o novamente antes que a publicação exista.
Depois da publicação, use uma nova versão para mudanças.

## Conteúdo do pacote

O ZIP contém o TOC, todos os arquivos listados nele, `README.md`, `CHANGELOG.md`, `LICENSE`
e os arquivos Markdown em `docs/`, exceto qualquer pasta `contributing`.
Os módulos de depuração ficam no pacote porque o TOC os carrega; eles só são ativados no modo de depuração.

Testes, ferramentas, workflows, documentos de contribuição, arquivos do site, imagens e configurações locais ficam fora.
A ferramenta redireciona links de páginas de contribuição e imagens excluídas para os arquivos da tag no GitHub.
O GitHub também oferece arquivos de código-fonte automáticos. Os jogadores devem usar o pacote anexado `Atlasium-v*.zip`.
