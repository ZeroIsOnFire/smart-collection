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
- **Fallback Crítico (Lanczos)**: Se todos os motores Real-ESRGAN falharem ou não estiverem disponíveis, o serviço realiza um redimensionamento clássico de alta qualidade usando `cv2.INTER_LANCZOS4`.
- **Autenticação**: Requer o header `X-API-Key` correspondente à variável de ambiente `IMAGE_UPSCALE_API_KEY` caso esteja configurada.

## ⚠️ Troubleshooting & Gotchas (Problemas Conhecidos)
- **PyTorch 2.6+ Crash**: O modelo Real-ESRGAN requer a desserialização de pesos que, a partir do PyTorch 2.6+, falha devido ao padrão restritivo de `weights_only=True` no `torch.load`. É **mandatório** manter o monkeypatch ativo no topo de `main.py` para forçar `weights_only=False` antes de carregar o stack do Real-ESRGAN.
- **Pre-loading no Boot**: O serviço tenta pré-carregar o modelo selecionado durante o evento `startup` da aplicação FastAPI. Se faltarem arquivos de pesos ou houver problemas de ambiente, erros explícitos serão emitidos nos logs do container, mantendo o serviço operacional em modo fallback Lanczos.
