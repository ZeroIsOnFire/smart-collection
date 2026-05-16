# Plano: upscale híbrido por ENV com Real-ESRGAN GPU e fallback CPU

## Objetivo
Implementar um fluxo parametrizável por variavel de ambiente para o microservico de upscale:

- `USE_GPU_UPSCALER=true` usa `Real-ESRGAN` completo via GPU como caminho principal.
- `USE_GPU_UPSCALER=false` usa `RealESRGAN_x4v3` como fallback leve em CPU.

O comportamento padrao deve ser `true`, priorizando a solucao mais forte quando houver GPU disponivel.

## Escopo

- Ajustar `upscale/main.py` para escolher o motor correto com base em `USE_GPU_UPSCALER`.
- Manter a resposta HTTP atual do endpoint `/upscale`.
- Preservar o resize final para `1080x1080` quando necessario.
- Garantir fallback seguro em caso de falha do modelo principal.

## Fluxo proposto

1. Ler `USE_GPU_UPSCALER` no arranque do servico.
2. Se estiver habilitado:
   - carregar o `Real-ESRGAN` principal para GPU;
   - executar inferencia com `half=True` quando suportado;
   - em caso de erro, cair para o fallback CPU.
3. Se estiver desabilitado:
   - usar `RealESRGAN_x4v3` em CPU como caminho principal;
   - se o modelo nao carregar ou falhar, cair para resize Lanczos.
4. Normalizar a saida final para `1080x1080` com recorte central.

## Requisitos de implementacao

- Nao expor a chave de API em logs.
- Manter o service leve e previsivel.
- Evitar dependencias novas sem necessidade clara.
- Preferir cache de modelos carregados uma unica vez.

## Arquivos provaveis

- `upscale/main.py`
- `upscale/Dockerfile`
- `upscale/requirements.txt`
- `spec/services/image_upscaler_service_spec.rb`
- novos testes do microservico, se necessario

## Proxima etapa sugerida

- Antes de codar, definir quais pesos serao baixados no build do container e quais serao carregados sob demanda.

