# SCC - Servico de Upscale de Imagens

[Read in English](README.md)

Microservico FastAPI usado pelo Rails para preparar fotos antes do salvamento final e antes da autodeteccao. O endpoint principal recebe uma imagem e devolve um JPEG com proporcao preservada e lado minimo garantido.

## Endpoints HTTP

- `GET /health`: retorna status, runtime ativo, caminho do modelo e parametros dos tiers.
- `POST /upscale?minimum_side=<px>`: recebe multipart `file`; retorna `image/jpeg`.

Quando `IMAGE_UPSCALE_API_KEY` estiver configurada, envie o header `X-API-Key`.

## Runtimes

O runtime e definido pelo Dockerfile usado pelo servico `upscale-service`.

| Dockerfile | Runtime | Modelo |
| --- | --- | --- |
| `Dockerfile.cpu` | CPU | `realesr-general-x4v3.pth` |
| `Dockerfile.nvidia` | NVIDIA/CUDA | `4x_NMKD-Siax_200k.pth` |
| `Dockerfile.amd` | AMD/ROCm | `4x_NMKD-Siax_200k.pth` |
| `Dockerfile.vulkan` | Vulkan/ncnn experimental | `realesrgan-x4plus` |

## Recomendacao Atual

Para desenvolvimento local no Windows/Docker Desktop, use `Dockerfile.cpu`. O runtime Vulkan sobe nesse ambiente, mas nao recebe uma GPU real dentro do container; ele enxerga `llvmpipe`, que e Vulkan por CPU.

Diagnostico observado no container:

```text
deviceType = PHYSICAL_DEVICE_TYPE_CPU
deviceName = llvmpipe (LLVM 19.1.7, 256 bits)
driverName = llvmpipe
```

Tambem foi verificado que o container nao recebe `/dev/dri` nem `/dev/dxg`. No host WSL existe `/dev/dxg`, mas ele nao chega ao container do Docker Desktop neste setup. Por isso, Vulkan no Docker Desktop/Windows nao deve ser tratado como aceleracao por GPU neste projeto.

Opcoes recomendadas:

- **CPU**: melhor padrao local quando compatibilidade e previsibilidade importam.
- **AMD/ROCm no WSL2 validado**: melhor opcao com GPU AMD neste ambiente, apesar da imagem grande.
- **Vulkan em Linux nativo**: candidato experimental quando o container receber `/dev/dri` e `vulkaninfo` listar uma GPU fisica.

O `Dockerfile.amd` esta fixado em `rocm/pytorch:rocm6.4.2_ubuntu24.04_py3.12_pytorch_release_2.6.0`, que foi a combinacao validada no WSL2 com AMD.

> **Aviso de tamanho no Windows/WSL2:** o caminho AMD/ROCm usa uma imagem base muito grande. Em ambientes Windows com WSL2, o build/pull e as camadas intermediarias podem consumir perto de **90 GB**. Planeje espaco em disco antes de testar esse runtime e prefira `Dockerfile.cpu` em maquinas com armazenamento limitado.

Nao ha divisao entre Dockerfiles AMD para Linux e Windows porque ambos continuam dependendo da imagem ROCm/PyTorch validada. Para AMD, as melhores alternativas sao:

- rodar em Linux nativo com ROCm quando houver GPU AMD compativel e espaco em disco suficiente;
- usar `Dockerfile.cpu` quando simplicidade, tamanho menor e compatibilidade forem mais importantes que desempenho;
- manter Windows/WSL2 apenas quando a GPU/ROCm estiver validada localmente e o custo de armazenamento for aceitavel.

### Runtime Vulkan Experimental

`Dockerfile.vulkan` oferece uma alternativa experimental baseada em `Real-ESRGAN-ncnn-vulkan`. Ele usa `UPSCALE_RUNTIME=vulkan`, chama o binario ncnn por arquivos temporarios e preserva o fallback Lanczos se a execucao falhar.

Esse caminho pode ser uma opcao cross-vendor para AMD, NVIDIA e Intel em hosts Linux com Vulkan funcional, mas nao substitui os runtimes PyTorch atuais. O Dockerfile baixa o pacote oficial `realesrgan-ncnn-vulkan-20220424-ubuntu.zip` da release `v0.2.5.0` do `xinntao/Real-ESRGAN`, que ja inclui o binario e os modelos ncnn.

A saida pode diferir do modelo `4x_NMKD-Siax_200k.pth` usado nos runtimes NVIDIA/AMD.

No Windows, o binario upstream nativo pode ser avaliado fora do Docker. Docker com GPU/Vulkan em Windows/WSL2 nao e um caminho validado neste projeto; para container com GPU Vulkan real, prefira Linux nativo com `/dev/dri`.

## Modelos Compativeis

Os runtimes GPU (`Dockerfile.amd` e `Dockerfile.nvidia`) usam a arquitetura `RRDBNet` 4x do Real-ESRGAN:

```text
num_feat=64, num_block=23, num_grow_ch=32, scale=4
```

Para trocar o modelo sem alterar codigo, monte ou copie o peso `.pth` para dentro do container e defina `REAL_ESRGAN_MODEL_PATH` no `docker-compose.yml` local:

```yaml
upscale-service:
  environment:
    - REAL_ESRGAN_MODEL_PATH=/app/models/meu-modelo.pth
```

O modelo precisa ser um peso ESRGAN/RRDB 4x compativel com essa arquitetura. Modelos SRVGG, compactos, 2x/8x ou com outra topologia nao carregam nesse backend sem alterar codigo.

Modelos RRDB 4x ja testados no backend AMD e compativeis com o caminho GPU atual:

| Modelo | Observacao |
| --- | --- |
| `4x-UltraSharp.pth` | Compativel com o mesmo `RRDBNet`. Nao e compativel com o caminho CPU atual sem alterar codigo. |
| `RealESRGAN_x4plus.pth` | Baseline anterior do projeto. Nao e compativel com o caminho CPU atual sem alterar codigo. |
| `4x_foolhardy_Remacri.pth` | Compativel com o mesmo `RRDBNet`. Nao e compativel com o caminho CPU atual sem alterar codigo. |
| `4x_NMKD-Siax_200k.pth` | Padrao atual para GPU. Nao e compativel com o caminho CPU atual sem alterar codigo. |
| `4xNomos8kSC.pth` | Compativel com o mesmo `RRDBNet`. Nao e compativel com o caminho CPU atual sem alterar codigo. |

O runtime CPU atual usa `SRVGGNetCompact` 4x:

```text
num_feat=64, num_conv=32, upscale=4, act_type=prelu
```

Modelo compativel com o caminho CPU atual:

| Modelo | Observacao |
| --- | --- |
| `realesr-general-x4v3.pth` | Padrao atual para CPU. Nao e compativel com o caminho GPU/RRDB atual sem alterar codigo. |

Se o peso customizado falhar no preload ou na inferencia, o servico continua online e a requisicao cai para Lanczos4.

## Tiers de Upscale

O servico escolhe a estrategia usando:

```text
ratio = current_min_side / minimum_side
```

- `ratio < TIER_4X_THRESHOLD` (`0.50` por padrao): Real-ESRGAN 4x.
- `TIER_4X_THRESHOLD <= ratio < TIER_2X_THRESHOLD` (`0.75` por padrao): Real-ESRGAN 2x.
- `ratio >= TIER_2X_THRESHOLD`: Lanczos4 com denoise/sharpen, sem IA.

Depois de qualquer upscale por IA, a imagem e reduzida para bater exatamente o lado minimo solicitado.

## Variaveis de Ambiente

- `IMAGE_UPSCALE_API_KEY`: chave opcional exigida no header `X-API-Key`.
- `IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE`: lado minimo usado quando `/upscale` recebe chamada sem `minimum_side` explicito.
- `REAL_ESRGAN_MODEL_PATH`: caminho customizado de modelo dentro do container escolhido.
- `VULKAN_BINARY_PATH`: caminho do binario `realesrgan-ncnn-vulkan` no runtime Vulkan.
- `VULKAN_MODEL_DIR`: diretorio dos modelos ncnn no runtime Vulkan.
- `VULKAN_MODEL_NAME`: nome do modelo ncnn usado pelo runtime Vulkan.
- `TIER_4X_THRESHOLD` / `TIER_2X_THRESHOLD`: limites dos tiers.
- `DENOISE_H`, `DENOISE_TEMPLATE_WINDOW`, `DENOISE_SEARCH_WINDOW`: parametros do denoise Lanczos.
- `LANCZOS_CAS_AMOUNT`: intensidade do sharpen CAS no fallback Lanczos.

## AMD/ROCm no WSL2

No WSL2 com AMD, o Docker deve ser executado a partir do Linux/WSL, nao do PowerShell, porque os paths montados existem no filesystem do WSL.

### Verificar o WSL

```sh
ls -l /dev/dxg /usr/lib/wsl/lib/libdxcore.so /opt/rocm/lib/libhsa-runtime64.so.1
cat /opt/rocm/.info/version
docker compose version
```

O setup validado tinha:

- `/dev/dxg` disponivel;
- `libdxcore.so` em `/usr/lib/wsl/lib/libdxcore.so`;
- `libhsa-runtime64.so.1` em `/opt/rocm/lib/libhsa-runtime64.so.1`;
- ROCm `6.4.2`;
- GPU detectada dentro do container como `AMD Radeon RX 9070 XT`.

### Configurar o `docker-compose.yml` Local

O `docker-compose.yml` local nao e versionado. Para AMD/WSL2, deixe o `upscale-service` com o Dockerfile AMD e as montagens abaixo:

```yaml
upscale-service:
  build:
    context: ./upscale
    dockerfile: Dockerfile.amd
  devices:
    - "/dev/dxg:/dev/dxg"
  volumes:
    - "/usr/lib/wsl/lib/libdxcore.so:/usr/lib/libdxcore.so:ro"
    - "/opt/rocm/lib/libhsa-runtime64.so.1:/opt/rocm/lib/libhsa-runtime64.so.1:ro"
  security_opt:
    - seccomp=unconfined
```

Para Linux AMD nativo, use o padrao ROCm com `/dev/kfd` e `/dev/dri` em vez de `/dev/dxg`.

Se o objetivo for evitar a imagem ROCm/PyTorch grande, use `Dockerfile.cpu`. O runtime Vulkan experimental pode ser avaliado em Linux com Vulkan funcional, mas deve ser tratado como opt-in ate haver validacao visual e de desempenho com fotos reais do projeto.

### Subir pelo WSL

```sh
cd /mnt/c/Users/junio/OneDrive/Documentos/git/smart-collection
docker compose up -d --build upscale-service
```

### Validar GPU

```sh
docker compose ps upscale-service
docker compose logs --tail=80 upscale-service
docker compose exec upscale-service python - <<'PY'
import torch
import main
print("model_path", main.model_path_for_runtime("amd"))
print("cuda_available", torch.cuda.is_available())
print("device_count", torch.cuda.device_count())
print("device_name", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "none")
PY
```

Resultado esperado:

- container `healthy`;
- logs com `Target mode: AMD`;
- logs com `AMD upscaler model pre-loaded successfully!`;
- `cuda_available True`.

O aviso `Can't initialize amdsmi - Error code: 34` pode aparecer no WSL2; ele nao impediu o PyTorch de usar a GPU no ambiente validado.

## Cuidados

- Mantenha o monkeypatch de `torch.load(weights_only=False)` antes de importar Real-ESRGAN.
- Mantenha o shim `torchvision.transforms.functional_tensor` para compatibilidade do `basicsr`.
- O modelo GPU atual e `4x_NMKD-Siax_200k.pth`; ele foi escolhido apos comparacao local no backend AMD com fotos reais do projeto.
- Se o pre-load do modelo falhar, o servico continua de pe e cai para Lanczos nas requisicoes.
- O Rails so deve chamar este servico quando `IMAGE_UPSCALE_SERVICE_URL` estiver configurada e o usuario permitir IA no fluxo aplicavel.

## Testes

Rode os testes do microservico a partir da raiz do projeto. Se o Python local nao tiver as dependencias, use o container:

```sh
docker compose run --rm -v "$PWD/upscale:/app" upscale-service python -m unittest test_main.py
```
