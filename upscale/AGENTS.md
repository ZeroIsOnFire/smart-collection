# AGENTS.md - SCC Image Upscale Service

## Visão Geral
Microserviço local especializado para upscale inteligente de imagens com base em modelos Real-ESRGAN (Super-Resolução), otimizado para CPU/GPU. Melhora a nitidez e a resolução de fotos e recortes de itens antes da autodetecção ou salvamento final.

## Stack Tecnológica
- **Base padrão**: `python:3.11-slim` em `Dockerfile`
- **Base AMD/ROCm**: `rocm/pytorch:latest` em `Dockerfile.amd`
- **Framework API**: FastAPI + Uvicorn
- **Motor de Inferência**: Real-ESRGAN (via PyTorch / torchvision)
- **Fallbacks de imagem**: denoise OpenCV + `cv2.INTER_LANCZOS4`
- **Modelos**:
  - `4x-UltraSharp.pth` (GPU / Alta Fidelidade — fotorrealista, sem efeito de pintura)
  - `realesr-general-x4v3.pth` (CPU / Fallback Leve)
  - `ESPCN_x4.pb` (fallback OpenCV — não mais usado ativamente, mantido para compatibilidade)

## Contrato HTTP
- `GET /health`: retorna status, modo alvo (`gpu`/`cpu`) e parâmetros ativos de tier/denoise.
- `POST /upscale?minimum_side=<px>`: recebe multipart `file` e retorna `image/jpeg`.
- `minimum_side` deve ser positivo. Arquivos vazios ou inválidos retornam erro `422`.
- A saída preserva proporção; não force saída quadrada se o pipeline atual estiver preservando aspect ratio.

## Regras e Funcionamento

### Sistema de 3 Camadas (Tier System)
O motor de decisão é baseado no **ratio** entre o lado menor atual da imagem e o `minimum_side` solicitado:

```
ratio = current_min_side / minimum_side
```

| Tier | Condição | Ação |
|------|----------|------|
| **Tier 1 — 4x AI** | `ratio < TIER_4X_THRESHOLD` (padrão `0.50`) | Real-ESRGAN 4x — reconstrução neural densa |
| **Tier 2 — 2x AI** | `TIER_4X_THRESHOLD <= ratio < TIER_2X_THRESHOLD` (padrão `0.75`) | Denoise + Real-ESRGAN 2x — boost moderado |
| **Tier 3 — Lanczos** | `ratio >= TIER_2X_THRESHOLD` | Denoise + Lanczos4 — redimensionamento clássico |

- **Denoise**: Utiliza `cv2.fastNlMeansDenoisingColored` antes do upscale nos Tiers 2 e 3.
- **Downscale pós-AI**: Após os Tiers 1 e 2, o resultado (que pode ultrapassar o target em incrementos de 4x ou 2x) é sempre redimensionado de volta para `minimum_side` via Lanczos4.
- **Fallback Crítico**: Qualquer falha nos modelos de IA resulta em Lanczos4 puro, garantindo que o serviço nunca retorne erro 500 por ausência de GPU ou modelo.

### Autenticação
Requer o header `X-API-Key` correspondente à variável de ambiente `IMAGE_UPSCALE_API_KEY` quando configurada.

## Testes e Qualidade
- Os testes vivem em `upscale/test_main.py` e usam `unittest` + `fastapi.testclient`.
- Antes de concluir mudanças neste serviço, rode `python -m unittest upscale/test_main.py` a partir da raiz do repositório ou o comando equivalente dentro do container.
- Testes devem mockar os upscalers pesados sempre que possível; não baixe modelos nem dependa de GPU em testes unitários.
- Ao alterar thresholds, fallback ou tamanho final, atualize também as specs Rails que exercitam `ImageUpscalerService`, `ImageCropperService`, `CarService` e `AutodetectionService`.

## Variáveis de Ambiente

| Variável | Padrão | Descrição |
| --- | --- | --- |
| `USE_GPU_UPSCALER` | `true` | Se `true`, tenta usar CUDA/GPU. Cai em CPU em caso de falha. |
| `IMAGE_UPSCALE_API_KEY` | _(vazio)_ | Chave de autenticação do header `X-API-Key`. Sem ela, qualquer chamada é aceita. |
| `REAL_ESRGAN_GPU_MODEL_PATH` | `/app/models/4x-UltraSharp.pth` | Caminho do modelo GPU dentro do container. |
| `REAL_ESRGAN_CPU_MODEL_PATH` | `/app/models/realesr-general-x4v3.pth` | Caminho do modelo CPU dentro do container. |
| `TIER_4X_THRESHOLD` | `0.50` | Ratio abaixo do qual o Real-ESRGAN 4x é acionado. |
| `TIER_2X_THRESHOLD` | `0.75` | Ratio abaixo do qual o Real-ESRGAN 2x é acionado. Acima, usa Lanczos. |
| `DENOISE_H` | `5` | Força do filtro de denoise (fastNlMeansDenoisingColored). Valores maiores = mais agressivo. |
| `DENOISE_TEMPLATE_WINDOW` | `7` | Tamanho da janela de template para o denoise. |
| `DENOISE_SEARCH_WINDOW` | `21` | Tamanho da janela de busca para o denoise. |


## ⚠️ Troubleshooting & Gotchas (Problemas Conhecidos)
- **PyTorch 2.6+ Crash**: O modelo Real-ESRGAN requer a desserialização de pesos que, a partir do PyTorch 2.6+, falha devido ao padrão restritivo de `weights_only=True` no `torch.load`. É **mandatório** manter o monkeypatch ativo no topo de `main.py` para forçar `weights_only=False` antes de carregar o stack do Real-ESRGAN.
- **Compatibilidade torchvision/basicsr**: O `main.py` cria um módulo `torchvision.transforms.functional_tensor` em runtime para manter o `basicsr` compatível com versões modernas do torchvision. Não remova esse shim sem substituir a compatibilidade.
- **Suporte a AMD GPU (ROCm)**: O código Python suporta AMD nativamente (`torch.cuda.is_available()` é mapeado e funciona). No entanto, o Docker Desktop no Windows **não suporta passthrough de GPU AMD** via `/dev/kfd`. Para rodar com GPU AMD, é necessário ambiente Linux nativo ou WSL2 com suporte explícito ao ROCm.
- **Pre-loading no Boot**: O serviço tenta pré-carregar o modelo selecionado durante o evento `startup` da aplicação FastAPI. Se faltarem arquivos de pesos ou houver problemas de ambiente, erros explícitos serão emitidos nos logs do container, mantendo o serviço operacional em modo fallback Lanczos.
- **Downscale Obrigatório**: Após qualquer upscale de IA (Tier 1 ou Tier 2), **sempre** aplicar `downscale_to_target()`. Os modelos operam em incrementos fixos (4x ou 2x) e a imagem resultante frequentemente excede `minimum_side`.
