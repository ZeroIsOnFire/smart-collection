# Plano: Upscale por usuario

## Objetivo

Adicionar uma preferencia por usuario para controlar o uso do upscaler por IA no processamento de imagens, mantendo um upscale simples por ImageMagick no fluxo de autodeteccao quando o servico de IA estiver indisponivel ou desabilitado pelo usuario.

## Etapas

1. Adicionar `ai_upscaling_enabled` ao model `User`, booleano com `default: true`.
2. Permitir atualizacao do parametro via Devise em `ApplicationController#configure_permitted_parameters`.
3. Exibir a opcao no painel de configuracoes somente quando `ImageUpscalerService.service_configured?`.
4. Incluir observacao abaixo da opcao explicando que:
   - a mudanca afeta apenas imagens adicionadas depois da alteracao;
   - imagens antigas permanecem conforme inseridas;
   - o upscaler por IA pode gerar artefatos;
   - imagens muito pequenas podem melhorar com o recurso.
5. Exibir aviso abaixo dos uploads de foto quando o usuario estiver com IA habilitada e o servico configurado:
   - upload geral: imagens abaixo de 360px podem receber upscale por IA;
   - autodeteccao: imagens abaixo de 1080px podem receber upscale por IA.
6. Refatorar `ImageUpscalerService` para separar:
   - upscale remoto por IA;
   - upscale simples local via MiniMagick/ImageMagick;
   - decisao por usuario/contexto.
7. Aplicar as regras:
   - uploads gerais usam IA apenas quando o usuario habilitou e o servico esta configurado;
   - uploads gerais nao usam IA quando o usuario desabilitou;
   - autodeteccao sempre garante imagem minima para YOLO;
   - autodeteccao usa upscale simples local quando IA estiver desabilitada ou indisponivel.
8. Propagar a preferencia por usuario em `CarService`, `AutodetectionService`, `ImageCropperService`, `AutodetectJob` e `DetectedItemsController`.
9. Alterar a descricao da autodeteccao para indicar que ela detecta multiplos veiculos e cria registros rapidamente, mas nao detecta o nome/modelo do veiculo.
10. Alterar `AutodetectJob` para nao usar o label retornado pelo YOLO como nome do item; usar label generico traduzido.
11. Cobrir com specs antes da implementacao:
    - default do usuario;
    - update da preferencia;
    - decisoes de upscale por usuario;
    - fallback local da autodeteccao;
    - label generico no job;
    - exibicao condicional da configuracao/avisos.
12. Validar com specs focadas e depois `docker compose exec web bundle exec rspec`.
