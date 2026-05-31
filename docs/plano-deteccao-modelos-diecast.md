# Plano: Deteccao de modelos de carros e miniaturas diecast

## Objetivo

Avaliar, em alto nivel, caminhos para enriquecer a autodeteccao com identificacao de marca/modelo de carros reais e, quando possivel, de miniaturas diecast como Hot Wheels, Mini GT, Matchbox e similares.

## Escopo inicial

1. Buscar bases prontas para deteccao/classificacao de modelos de carros.
2. Verificar se existem bases abertas ou acessiveis para modelos de miniaturas diecast.
3. Caso nao exista base pronta adequada, buscar projetos, wikis ou catalogos que possam ser usados como fonte de extracao.
4. Se as fontes externas forem insuficientes, avaliar a criacao de uma base propria.

## Analise superficial

### Bases de carros reais

Existem datasets publicos e academicos para reconhecimento de marca/modelo de carros reais. Eles parecem uteis como ponto de partida para identificar o veiculo base, mas nao resolvem diretamente a identificacao de uma miniatura especifica.

Fontes encontradas:

- VMMRdb: dataset grande para reconhecimento de marca/modelo/ano, com mencoes a 9.170 classes e 291.752 imagens.
  - https://fmi-data-index.github.io/tencent_ml.html
  - https://openaccess.thecvf.com/content_cvpr_2017_workshops/w9/papers/Tafazzoli_A_Large_and_CVPR_2017_paper.pdf
- Mendeley Data: "Vehicle images dataset for make and model recognition".
  - https://data.mendeley.com/datasets/hj3vvx5946/1
- Outros datasets de VMMR podem ajudar na classificacao geral, mas tendem a focar em carros reais em ambiente de transito, nao em fotos de colecionador.

Leitura inicial: aproveitar esses datasets pode ajudar a sugerir "Nissan Skyline", "Porsche 911", "Ford Mustang" etc., mas nao deve ser tratado como identificador de item colecionavel, serie, ano de blister, cor, variacao ou fabricante diecast.

### Bases de Hot Wheels e diecast

Nao apareceu, nesta busca rapida, uma base aberta claramente pronta para treinar deteccao visual de modelos Hot Wheels/Mini GT/Matchbox por imagem. O que existe com mais forca sao catalogos, wikis e apps de colecionadores.

Fontes/catalogos encontrados:

- Hot Wheels Wiki/Fandom: catalogo amplo por modelos, listas, series e anos.
  - https://hotwheels.fandom.com/wiki/Hot_Wheels
  - https://hotwheels.fandom.com/wiki/List_of_Hot_Wheels
  - https://hotwheels.fandom.com/wiki/Category:Licensed_Hot_Wheels
- MainlineDB: base gratuita de Hot Wheels Mainline, com foco em 2000 ate o presente.
  - https://mainlinedb.com/
- Miniaturecar Museum: database com aproximadamente 160.000 registros de miniaturas.
  - https://minicarmuseum.com/database/mmdbsearch_en.php
- HWBase: tracker/catalogo fan-made de Hot Wheels.
  - https://hwbase.com/
- PopRace.org: wiki fan-made de Pop Race, com modelos, variacoes e box versions.
  - https://poprace.org/
- MicroGarage e Diecast Hub indicam que existem catalogos comunitarios e produtos com preenchimento por foto, mas nao ficou claro se ha acesso aberto a dataset/API.
  - https://www.microgarage.app/en/home
  - https://diecasthub.app/

Leitura inicial: o caminho mais realista parece ser usar essas fontes como catalogo textual/visual de referencia, com cuidado juridico e operacional, em vez de assumir que existe um dataset de treino pronto.

### Extracao de wikis/catalogos

Se nao houver dataset visual pronto, o proximo caminho e montar uma pipeline de extracao e normalizacao:

1. Usar APIs oficiais quando existirem.
2. Para Fandom/MediaWiki, avaliar a API de categoria/paginas antes de qualquer scraping HTML.
   - https://www.mediawiki.org/wiki/API:Categorymembers
3. Extrair campos minimos:
   - marca diecast;
   - nome do casting/modelo;
   - ano/serie;
   - cor;
   - escala;
   - codigo/collector number quando existir;
   - imagens de referencia quando permitido;
   - URL da fonte.
4. Normalizar nomes, aliases e fabricantes reais.
5. Guardar proveniencia e data de coleta para auditoria.

Ponto de atencao: licenca, termos de uso e direitos de imagem precisam ser verificados antes de baixar imagens em massa ou usar conteudo em treino de modelo.

## Caminho recomendado

1. Fase 1: Prova de conceito sem treino novo.
   - manter YOLO apenas para detectar/localizar veiculos na foto;
   - usar OCR/visao ou embeddings de imagem para comparar o recorte com um catalogo pequeno curado;
   - retornar sugestoes com score, nunca preencher automaticamente como verdade.

2. Fase 2: Catalogo proprio incremental.
   - criar modelo de dados para catalogo de referencias;
   - importar uma amostra pequena de fontes permitidas;
   - permitir correcao manual pelo usuario;
   - transformar confirmacoes do usuario em exemplos revisaveis.

3. Fase 3: Dataset proprio.
   - coletar imagens autorizadas dos usuarios ou curadoria interna;
   - rotular por marca diecast, casting, serie, cor e ano;
   - separar treino/validacao/teste;
   - avaliar fine-tuning ou busca vetorial por imagem antes de treinar um detector/classificador pesado.

## Resultado da avaliacao

Resultado preliminar: existem bases boas para carros reais, mas nao foi encontrado, nesta analise rapida, um dataset aberto e pronto para deteccao visual de modelos Hot Wheels/Mini GT/Matchbox com granularidade de colecionador.

Recomendacao: seguir primeiro por catalogo/lookup assistido e curadoria propria. A solucao deve tratar a identificacao como "sugestao" ate haver base validada suficiente, evitando preencher marca/modelo/serie automaticamente com baixa confianca.

## Proximos passos

1. Verificar termos de uso/licencas das fontes candidatas.
2. Fazer um spike tecnico com a API do Fandom/MediaWiki em uma categoria pequena.
3. Comparar abordagem de OCR + busca textual contra embeddings de imagem em 20 a 50 exemplos.
4. Definir um schema de catalogo interno antes de qualquer importacao grande.
5. Decidir se o produto precisa reconhecer apenas o carro real base ou tambem a miniatura exata.
