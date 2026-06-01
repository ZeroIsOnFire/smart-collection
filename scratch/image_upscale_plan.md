# Planejamento de upscale local por IA

## Objetivo
Adicionar um fluxo de melhora de imagem com upscale local em CPU, usando um motor de IA como primeira opcao e mantendo o comportamento atual de fallback com MiniMagick quando necessario.

## Regras acordadas
- Imagens com o menor lado abaixo de 512px devem passar pelo upscale local.
- O fluxo de Vision continua com a regra atual de 1080px para o menor lado.
- A logica deve ficar em services, com testes RSpec cobrindo o novo comportamento.

## Sequencia
1. Criar um service central para decidir quando upscale eh necessario.
2. Integrar esse service nos fluxos de recorte, deteccao de Vision e processamento do carro.
3. Preservar o comportamento atual de PDF e demais telas, que passam a herdar a imagem melhorada.
4. Manter fallback seguro para MiniMagick caso o motor local de IA nao esteja disponivel.

