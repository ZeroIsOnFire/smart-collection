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
  - `ESPCN_x4.pb` (CPU / Intermediário super leve via OpenCV)

## Regras e Funcionamento
- **Modo Híbrido**: O microserviço é dinâmico. Se `USE_GPU_UPSCALER=true` (padrão) e CUDA estiver disponível, executa em GPU. Caso contrário, ou sob falha, faz o fallback para processamento leve em CPU usando o modelo `realesr-general-x4v3`.
- **Threshold Guard (Anti-Distorção)**: Antes de acionar a rede neural pesada, o serviço avalia o tamanho da imagem em relação ao alvo (mínimo exigido).
  - **Modo CPU (Sistema de 3 Camadas)**:
    - **< `AI_UPSCALE_THRESHOLD_CPU` (default: `0.66`)**: Usa *Real-ESRGAN* (a imagem é muito pequena e precisa de reconstrução neural densa).
    - **Entre `0.66` e `AI_UPSCALE_THRESHOLD_ESPCN_CPU` (default: `0.85`)**: Usa *OpenCV ESPCN* (a imagem é mediana; o modelo ESPCN não distorce nem gera "efeito pintura a óleo", apenas adiciona nitidez limpa).
    - **>= `0.85`**: Ignora IA totalmente e usa apenas o redimensionamento clássico *Lanczos4*.
  - **Modo GPU (Sistema de 2 Camadas)**: Como a GPU usa o modelo `x4plus` que é de altíssima qualidade, atua até o limite `AI_UPSCALE_THRESHOLD_GPU` (default: `0.85`). Se maior que isso, pula para *Lanczos4*.
- **Fallback Crítico (Lanczos)**: Se todos os motores Real-ESRGAN/ESPCN falharem ou não estiverem disponíveis, o serviço realiza um redimensionamento clássico de alta qualidade usando `cv2.INTER_LANCZOS4`.
- **Autenticação**: Requer o header `X-API-Key` correspondente à variável de ambiente `IMAGE_UPSCALE_API_KEY` caso esteja configurada.

## Variáveis de Ambiente

| Variável | Padrão | Descrição |
| --- | --- | --- |
| `USE_GPU_UPSCALER` | `true` | Se `true`, tenta usar CUDA/GPU. Cai em CPU em caso de falha. |
| `IMAGE_UPSCALE_API_KEY` | _(vazio)_ | Chave de autenticação do header `X-API-Key`. Sem ela, qualquer chamada é aceita. |
| `REAL_ESRGAN_GPU_MODEL_PATH` | `/app/models/RealESRGAN_x4plus.pth` | Caminho do modelo GPU dentro do container. |
| `REAL_ESRGAN_CPU_MODEL_PATH` | `/app/models/realesr-general-x4v3.pth` | Caminho do modelo CPU dentro do container. |
| `AI_UPSCALE_THRESHOLD_CPU` | `0.66` | Fração do target abaixo da qual o Real-ESRGAN atua em modo CPU. |
| `AI_UPSCALE_THRESHOLD_GPU` | `0.85` | Fração do target abaixo da qual o Real-ESRGAN atua em modo GPU. |
| `AI_UPSCALE_THRESHOLD_ESPCN_CPU` | `0.85` | Fração do target até onde o modelo intermediário ESPCN atua em modo CPU. Acima disso, usa-se Lanczos. |


## ⚠️ Troubleshooting & Gotchas (Problemas Conhecidos)
- **PyTorch 2.6+ Crash**: O modelo Real-ESRGAN requer a desserialização de pesos que, a partir do PyTorch 2.6+, falha devido ao padrão restritivo de `weights_only=True` no `torch.load`. É **mandatório** manter o monkeypatch ativo no topo de `main.py` para forçar `weights_only=False` antes de carregar o stack do Real-ESRGAN.
- **Suporte a AMD GPU (ROCm)**: O código Python suporta AMD nativamente (`torch.cuda.is_available()` é mapeado e funciona). No entanto, o contêiner Docker atual baseia-se em `python:3.11-slim` sem suporte a ROCm. Para rodar em AMD, o usuário deve construir a imagem usando `rocm/pytorch` como base e rodar o contêiner passando `--device=/dev/kfd --device=/dev/dri --group-add video`.
- **Pre-loading no Boot**: O serviço tenta pré-carregar o modelo selecionado durante o evento `startup` da aplicação FastAPI. Se faltarem arquivos de pesos ou houver problemas de ambiente, erros explícitos serão emitidos nos logs do container, mantendo o serviço operacional em modo fallback Lanczos.
