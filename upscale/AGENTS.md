# AGENTS.md - SCC Image Upscale Service

## Visão Geral
Microserviço local especializado para upscale inteligente de imagens com base em modelos Real-ESRGAN (Super-Resolução), otimizado para CPU/GPU. Melhora a nitidez e a resolução de fotos e recortes de itens antes da autodetecção ou salvamento final.

## Stack Tecnológica
- **Base**: `python:3.11-slim`
- **Framework API**: FastAPI + Uvicorn
- **Motor de Inferência**: Real-ESRGAN (via PyTorch / torchvision)
- **Modelos**:
  - `RealESRGAN_x4plus.pth` (GPU / Alta Fidelidade)
  - `realesr-general-x4v3.pth` (CPU / Fallback Leve)

## Regras e Funcionamento
- **Modo Híbrido**: O microserviço é dinâmico. Se `USE_GPU_UPSCALER=true` (padrão) e CUDA estiver disponível, executa em GPU. Caso contrário, ou sob falha, faz o fallback para processamento leve em CPU usando o modelo `realesr-general-x4v3`.
- **Threshold Guard (Anti-Distorção)**: Antes de acionar a rede neural, o serviço verifica se a imagem de entrada já possui um tamanho "razoável" em relação ao alvo. Se o lado menor da imagem for maior ou igual a `minimum_side * threshold`, o upscale neural é **ignorado** e a imagem vai direto para o redimensionamento Lanczos4. Isso evita o efeito "pintura a óleo" que modelos leves de CPU introduzem em imagens que já possuem detalhes suficientes.
  - `AI_UPSCALE_THRESHOLD_CPU` (default: `0.66`): O modelo leve de CPU distorce mais facilmente → limite menor (só usa IA para imagens abaixo de 66% do target).
  - `AI_UPSCALE_THRESHOLD_GPU` (default: `0.85`): O modelo pesado de GPU é de alta fidelidade → pode atuar em imagens até 85% do target.
- **Fallback Crítico (Lanczos)**: Se todos os motores Real-ESRGAN falharem ou não estiverem disponíveis, o serviço realiza um redimensionamento clássico de alta qualidade usando `cv2.INTER_LANCZOS4`.
- **Autenticação**: Requer o header `X-API-Key` correspondente à variável de ambiente `IMAGE_UPSCALE_API_KEY` caso esteja configurada.

## Variáveis de Ambiente

| Variável | Padrão | Descrição |
| --- | --- | --- |
| `USE_GPU_UPSCALER` | `true` | Se `true`, tenta usar CUDA/GPU. Cai em CPU em caso de falha. |
| `IMAGE_UPSCALE_API_KEY` | _(vazio)_ | Chave de autenticação do header `X-API-Key`. Sem ela, qualquer chamada é aceita. |
| `REAL_ESRGAN_GPU_MODEL_PATH` | `/app/models/RealESRGAN_x4plus.pth` | Caminho do modelo GPU dentro do container. |
| `REAL_ESRGAN_CPU_MODEL_PATH` | `/app/models/realesr-general-x4v3.pth` | Caminho do modelo CPU dentro do container. |
| `AI_UPSCALE_THRESHOLD_CPU` | `0.66` | Fração do target abaixo da qual a IA atua em modo CPU. |
| `AI_UPSCALE_THRESHOLD_GPU` | `0.85` | Fração do target abaixo da qual a IA atua em modo GPU. |


## ⚠️ Troubleshooting & Gotchas (Problemas Conhecidos)
- **PyTorch 2.6+ Crash**: O modelo Real-ESRGAN requer a desserialização de pesos que, a partir do PyTorch 2.6+, falha devido ao padrão restritivo de `weights_only=True` no `torch.load`. É **mandatório** manter o monkeypatch ativo no topo de `main.py` para forçar `weights_only=False` antes de carregar o stack do Real-ESRGAN.
- **Pre-loading no Boot**: O serviço tenta pré-carregar o modelo selecionado durante o evento `startup` da aplicação FastAPI. Se faltarem arquivos de pesos ou houver problemas de ambiente, erros explícitos serão emitidos nos logs do container, mantendo o serviço operacional em modo fallback Lanczos.
