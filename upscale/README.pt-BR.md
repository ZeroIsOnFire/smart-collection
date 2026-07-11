# SCC - Serviço de Upscale de Imagens

[Read in English](README.md)

Microserviço FastAPI usado pelo Rails para preparar fotos de carros antes do salvamento final quando o upscale por IA está habilitado e `IMAGE_UPSCALE_SERVICE_URL` está configurada. O endpoint recebe uma imagem e devolve um JPEG com proporção preservada e lado mínimo garantido.

A análise de autodetecção deve continuar usando a imagem original enviada. O upscaler se aplica apenas ao fluxo de salvamento de fotos de carros.

## Endpoint

- `GET /health`: retorna status do serviço, runtime, modelo e parâmetros de processamento.
- `POST /upscale?minimum_side=<px>`: recebe multipart `file`; retorna `image/jpeg`.

Quando `IMAGE_UPSCALE_API_KEY` estiver configurada, envie o header `X-API-Key`.

## Runtimes

O runtime é definido pelo Dockerfile usado pelo `upscale-service`.

| Dockerfile | Runtime | Modelo |
| --- | --- | --- |
| `Dockerfile.cpu` | CPU | `realesr-general-x4v3.pth` |
| `Dockerfile.nvidia` | NVIDIA/CUDA | `4x_NMKD-Siax_200k.pth` |
| `Dockerfile.amd` | AMD/ROCm | `4x_NMKD-Siax_200k.pth` |
| `Dockerfile.vulkan` | Vulkan/ncnn experimental | `realesrgan-x4plus` |

Para desenvolvimento local no Windows/Docker Desktop, use `Dockerfile.cpu`. O runtime Vulkan pode subir nesse ambiente, mas normalmente enxerga `llvmpipe`, que é Vulkan por CPU, em vez de uma GPU real. Docker com GPU/Vulkan no Windows/WSL2 não é um caminho validado neste projeto.

Para AMD, prefira Linux nativo com ROCm quando possível. O `Dockerfile.amd` está fixado no caminho ROCm/PyTorch validado e pode consumir perto de **90 GB** no Windows/WSL2 por causa da imagem base e das camadas. Use CPU quando tamanho e compatibilidade forem mais importantes que desempenho.

## Docker Compose

Setup CPU padrão:

```yaml
upscale-service:
  build:
    context: ./upscale
    dockerfile: Dockerfile.cpu
  env_file:
    - .env
  environment:
    - IMAGE_UPSCALE_API_KEY=${IMAGE_UPSCALE_API_KEY:-}
    - REAL_ESRGAN_MODEL_PATH=${REAL_ESRGAN_MODEL_PATH:-}
    - TIER_4X_THRESHOLD=${TIER_4X_THRESHOLD:-0.50}
    - TIER_2X_THRESHOLD=${TIER_2X_THRESHOLD:-0.75}
  restart: unless-stopped
```

Suba ou reconstrua apenas o serviço:

```bash
docker compose up -d --build upscale-service
```

Confira o status:

```bash
docker compose ps upscale-service
docker compose logs --tail=80 upscale-service
```

Rails e Sidekiq devem chamar:

```text
http://upscale-service:8000
```

## Regras de processamento

O serviço usa o ratio entre o lado menor atual e o `minimum_side` solicitado:

```text
ratio = current_min_side / minimum_side
```

| Tier | Condição | Ação |
| --- | --- | --- |
| Tier 1 - IA 4x | `ratio < TIER_4X_THRESHOLD` (padrão `0.50`) | Real-ESRGAN 4x |
| Tier 2 - IA 2x | `TIER_4X_THRESHOLD <= ratio < TIER_2X_THRESHOLD` (padrão `0.75`) | Real-ESRGAN 2x |
| Tier 3 - Lanczos | `ratio >= TIER_2X_THRESHOLD` | Lanczos4 |

Depois de qualquer upscale por IA, a imagem é reduzida para que o lado menor bata exatamente o mínimo solicitado. Se o Real-ESRGAN falhar, o endpoint cai para Lanczos4 e continua funcional.

## Modelos

Os runtimes GPU usam `RRDBNet(num_feat=64, num_block=23, num_grow_ch=32, scale=4)`. Modelos RRDB 4x compatíveis já testados no backend AMD incluem:

- `4x-UltraSharp.pth`
- `RealESRGAN_x4plus.pth`
- `4x_foolhardy_Remacri.pth`
- `4x_NMKD-Siax_200k.pth`
- `4xNomos8kSC.pth`

O runtime CPU usa `SRVGGNetCompact(num_feat=64, num_conv=32, upscale=4, act_type=prelu)` com `realesr-general-x4v3.pth`. Não misture modelos RRDB de GPU no caminho CPU nem o modelo SRVGG de CPU no caminho GPU/RRDB sem mudanças de código e testes.

## Variáveis de ambiente

- `IMAGE_UPSCALE_API_KEY`: chave opcional exigida pelo header `X-API-Key`.
- `IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE`: lado mínimo usado quando o Rails ou o endpoint não informa valor explícito; padrão `360`.
- `REAL_ESRGAN_MODEL_PATH`: caminho opcional de modelo customizado dentro do container.
- `VULKAN_BINARY_PATH`: caminho do binário ncnn no runtime Vulkan.
- `VULKAN_MODEL_DIR`: diretório de modelos ncnn no runtime Vulkan.
- `VULKAN_MODEL_NAME`: nome do modelo ncnn no runtime Vulkan.
- `TIER_4X_THRESHOLD`: ratio abaixo do qual o Real-ESRGAN 4x é usado; padrão `0.50`.
- `TIER_2X_THRESHOLD`: ratio abaixo do qual o Real-ESRGAN 2x é usado; padrão `0.75`.
- `DENOISE_H`, `DENOISE_TEMPLATE_WINDOW`, `DENOISE_SEARCH_WINDOW`, `LANCZOS_CAS_AMOUNT`: parâmetros de melhoria do fallback.

## Notas de desenvolvimento

- Mantenha o monkeypatch `torch.load(weights_only=False)` antes de importar Real-ESRGAN.
- Mantenha o shim `torchvision.transforms.functional_tensor` para compatibilidade do `basicsr`.
- Não baixe modelos nem exija acesso a GPU em testes unitários.
- Não adicione dependências Python sem aprovação explícita.
- Se faltarem pesos ou GPU, o startup deve registrar o erro em log e o endpoint deve continuar com fallback Lanczos.

## Testes

Rode os testes unitários a partir da raiz do repositório:

```bash
python -m unittest upscale/test_main.py
```

Ou dentro do Docker Compose:

```bash
docker compose run --rm -v "$PWD/upscale:/app" upscale-service python -m unittest test_main.py
```
