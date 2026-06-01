# AGENTS.md - SCC Image Upscale Service

## Visao Geral
Microservico local para upscale inteligente de imagens com Real-ESRGAN e fallback Lanczos. Ele melhora nitidez e resolucao de fotos/recortes antes da autodeteccao ou do salvamento final.

## Stack Tecnologica
- **CPU**: `python:3.11-slim` em `Dockerfile.cpu`
- **NVIDIA/CUDA**: `pytorch/pytorch:*-cuda*-runtime` em `Dockerfile.nvidia`
- **AMD/ROCm**: `rocm/pytorch:latest` em `Dockerfile.amd`
- **API**: FastAPI + Uvicorn
- **Inferencia**: Real-ESRGAN via PyTorch/torchvision
- **Fallbacks**: `cv2.INTER_LANCZOS4`
- **Modelos por imagem**:
  - CPU baixa `realesr-general-x4v3.pth` e `realesr-general-wdn-x4v3.pth` (DNI para denoise strength)
  - NVIDIA baixa somente `RealESRGAN_x4plus.pth`
  - AMD baixa somente `RealESRGAN_x4plus.pth`

## Contrato HTTP
- `GET /health`: retorna status, runtime ativo, modelo ativo e parametros de tier/denoise.
- `POST /upscale?minimum_side=<px>`: recebe multipart `file` e retorna `image/jpeg`.
- `minimum_side` deve ser positivo. Arquivos vazios ou invalidos retornam erro `422`.
- A saida preserva proporcao; nao force saida quadrada.

## Regras e Funcionamento

### Runtime
O runtime e definido pela imagem Docker.

| Dockerfile | Runtime interno | Modelo baixado |
| --- | --- | --- |
| `Dockerfile.cpu` | `cpu` | `realesr-general-x4v3.pth` + `realesr-general-wdn-x4v3.pth` |
| `Dockerfile.nvidia` | `nvidia` | `RealESRGAN_x4plus.pth` |
| `Dockerfile.amd` | `amd` | `RealESRGAN_x4plus.pth` |

Nao reintroduza modelos antigos nem baixe pesos que nao pertencam ao Dockerfile escolhido.

### Sistema de 3 Camadas
O motor de decisao usa o ratio entre o lado menor atual e o `minimum_side` solicitado:

```text
ratio = current_min_side / minimum_side
```

| Tier | Condicao | Acao |
| --- | --- | --- |
| Tier 1 - 4x AI | `ratio < TIER_4X_THRESHOLD` (padrao `0.50`) | Real-ESRGAN 4x |
| Tier 2 - 2x AI | `TIER_4X_THRESHOLD <= ratio < TIER_2X_THRESHOLD` (padrao `0.75`) | Real-ESRGAN 2x |
| Tier 3 - Lanczos | `ratio >= TIER_2X_THRESHOLD` | Lanczos4 |

- Apos os Tiers 1 e 2, sempre aplique `downscale_to_target()`.
- Qualquer falha de Real-ESRGAN deve cair para Lanczos4, mantendo o endpoint funcional.
- Nao faca fallback entre modelos CPU/GPU dentro do runtime; se a imagem GPU falhar, use Lanczos.

### Autenticacao
Quando `IMAGE_UPSCALE_API_KEY` estiver configurada, as chamadas exigem o header `X-API-Key`.

## Testes e Qualidade
- Testes vivem em `upscale/test_main.py` e usam `unittest` + `fastapi.testclient`.
- Antes de concluir mudancas neste servico, rode `python -m unittest upscale/test_main.py` a partir da raiz do repositorio ou equivalente no container.
- Testes devem mockar os upscalers pesados; nao baixe modelos nem dependa de GPU em testes unitarios.

## Variaveis de Ambiente

| Variavel | Padrao | Descricao |
| --- | --- | --- |
| `IMAGE_UPSCALE_API_KEY` | vazio | Chave do header `X-API-Key`. Sem ela, qualquer chamada e aceita. |
| `REAL_ESRGAN_MODEL_PATH` | por runtime | Caminho customizado opcional para pesos dentro do container. |
| `REAL_ESRGAN_WDN_MODEL_PATH` | `/app/models/realesr-general-wdn-x4v3.pth` | Modelo WDN usado com CPU/DNI quando `REAL_ESRGAN_DENOISE_STRENGTH < 1`. |
| `REAL_ESRGAN_DENOISE_STRENGTH` | `0` | Denoise do `realesr-general-x4v3`: `0` preserva ruido, `1` aplica denoise forte. |
| `TIER_4X_THRESHOLD` | `0.50` | Ratio abaixo do qual o Real-ESRGAN 4x e acionado. |
| `TIER_2X_THRESHOLD` | `0.75` | Ratio abaixo do qual o Real-ESRGAN 2x e acionado. Acima, usa Lanczos. |
## Gotchas
- Mantenha o monkeypatch de `torch.load(weights_only=False)` antes de importar Real-ESRGAN.
- Mantenha o shim `torchvision.transforms.functional_tensor` para compatibilidade do `basicsr`.
- AMD/ROCm no Windows Docker Desktop nao tem passthrough simples via `/dev/kfd`; prefira Linux nativo ou WSL2 com ROCm suportado.
- Se faltarem pesos ou GPU, o startup deve logar o erro e o endpoint deve continuar com fallback Lanczos.
