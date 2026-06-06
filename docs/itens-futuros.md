# Itens futuros

Backlog de melhorias para avaliar e priorizar em sessoes futuras.
Use o checklist para marcar cada item quando for concluido.

## 1. Otimizacoes de desempenho

- [x] 1.1 Avaliar processamento por IA sempre em background via Sidekiq, exibindo estados como "processando" enquanto a tarefa roda.
- [x] 1.2 Aplicar o fluxo assincrono tanto na pagina de autodeteccao quanto na pagina de carros.
- [x] 1.3 Evitar processamentos pesados no request principal, especialmente ao salvar carro, subir fotos, fazer upscale ou chamar servicos de IA.
- [x] 1.4 Avaliar outras melhorias gerais de performance.

## 2. Upscale e processamento de imagens

- [ ] 2.1 Tentar achar um upscaler melhor para GPUs rapidas, como uma opcao "ultra premium"; como o processamento ficara em background, pode demorar ate 15 segundos se o usuario visualizar claramente que esta processando.
- [ ] 2.2 Remover o resize do autodetector quando o upscaler estiver desligado.
- [ ] 2.3 Exibir aviso quando as fotos receberem melhorias por IA.
- [ ] 2.4 Buscar opcoes de upscaler de imagens sem IA para testar, como AMD FSR1 ou alternativas equivalentes.
- [ ] 2.5 Avaliar algum melhorador de imagem de pos-processamento por IA para recuperar nitidez ou detalhes perdidos pelo upscaler.
- [ ] 2.6 Reduzir o tamanho padrao do upscale usado pelo YOLO/autodetector para 800p em vez de 1080p.

## 3. Melhorias de layout

- [ ] 3.1 Revisar botoes de gerar PDF e CSV para que nao parecam desabilitados antes da primeira execucao.
- [ ] 3.2 Melhorar estados visuais de botoes, cards e componentes transparentes/cinzas que possam dar impressao de acao indisponivel.
- [ ] 3.3 Avaliar melhorias na tela de detalhes/show dos carros.
- [ ] 3.4 Adicionar na visualizacao publica um modo carousel, com exibicao por galeria e design premium.

## 4. Estatisticas de uso e IA

- [ ] 4.1 Criar estatisticas por servico e por uso geral do sistema.
- [ ] 4.2 Medir quantidade de usuarios, carros cadastrados, itens detectados por YOLO e fotos que usaram upscaler.
- [ ] 4.3 Exibir essas informacoes no painel admin em uma pagina propria, separada da manutencao.
- [ ] 4.4 Remover da pagina de manutencao os itens semelhantes que forem melhor representados nessa nova pagina de estatisticas.

## 5. Relatorio PDF

- [ ] 5.1 Tentar deixar o relatorio PDF mais bonito e premium.
- [ ] 5.2 Avaliar capa, tipografia, organizacao das fotos, metadados dos itens e resumo da colecao.

## 6. Cadastro de itens

- [ ] 6.1 Verificar formas de facilitar ou simplificar cadastros.
- [ ] 6.2 Avaliar reducao de campos obrigatorios, preenchimento progressivo, atalhos, reaproveitamento de dados e sugestoes automaticas.
- [ ] 6.3 Deixar comportamento de atualizações de autodetecção mais consistente, cada processo trata a tela de um jeito.
- [x] 6.4 Remover o campo de fabricante do veiculo, mantendo marca e usando o nome para registrar fabricante + modelo.

## 7. Melhorias de login

- [ ] 7.1 Adicionar visualizacao de senha nos formularios de login e cadastro.
