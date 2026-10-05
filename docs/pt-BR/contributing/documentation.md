# Publicação da documentação

O site usa Doxygen para renderizar o Markdown do repositório. O tema usa o layout de wiki aprovado.
Inglês e português brasileiro têm páginas separadas. O controle de idioma mantém a página e a seção atuais.
O controle de tema seleciona o modo claro ou escuro e mantém a escolha.

## Fontes

- `README.md` é a página inicial em inglês. O título permanece na fonte.
  O site mostra o logo em vez de repetir o título visível.
- `docs/pt-BR/home.md` é a página inicial em português.
- Cada outro documento Markdown em `docs/` vira uma página.
  Os documentos de contribuição ficam em `docs/contributing/`.
- Os documentos em português repetem esses caminhos em `docs/pt-BR/`.
  Toda página em inglês precisa de tradução. Mantenha os mesmos níveis e a mesma ordem de títulos.
- `docs/site/` contém o modelo HTML, a folha de estilos e o script do navegador.
- `Doxyfile` contém as opções do renderizador. `tools/build_docs.py` prepara a entrada,
  executa o Doxygen e aplica o tema. Ele verifica links locais, imagens e âncoras de seções.

Edite as fontes Markdown. Não edite `.build/site/`; a próxima geração substitui seu conteúdo.
Mantenha comandos, nomes de API e exemplos de código iguais nas traduções.
As duas versões usam os IDs de seção em inglês para manter os links e as mudanças de idioma.

## Geração local

1. Instale Python 3.10 ou posterior e Doxygen 1.18.0 ou posterior. Adicione os executáveis ao `PATH`.
2. Na raiz do repositório, execute:

   ```
   python tools/build_docs.py
   ```

   Para um executável portátil, use `--doxygen "<caminho para doxygen.exe>"`.

3. Sirva o site gerado:

   ```
   python -m http.server 8000 --directory .build/site
   ```

4. Abra `http://localhost:8000/`. Confira os dois idiomas, os temas e a página alterada.

A geração não precisa de pacotes Python. `.gitignore` exclui as páginas geradas e as ferramentas locais.

## Configurar o GitHub Pages

1. Abra **Settings → Pages** no repositório.
2. Em **Build and deployment**, defina **Source** como **GitHub Actions**.
3. Envie a documentação e `.github/workflows/docs.yml` para `main`.
4. Abra **Actions → Documentation**. Aguarde a geração e a implantação.

O endereço do site é `https://1mamute.github.io/atlasium/`.
O workflow gera os dois idiomas, verifica os links e envia o artefato do site.
Usa a versão Linux oficial do Doxygen 1.18.0 e verifica a soma SHA-256.
A etapa de implantação publica esse artefato no ambiente `github-pages`.
Se o ambiente exigir aprovação, aprove a implantação em Actions.

## Publicar atualizações

1. Atualize o documento em inglês e a tradução em português.
2. Gere o site localmente e revise o resultado.
3. Faça o commit e envie as mudanças para `main`.
4. Confira o endereço publicado no workflow **Documentation**.

Pull requests geram e validam o site sem publicá-lo.
Você também pode iniciar o workflow em **Actions → Documentation → Run workflow**.
