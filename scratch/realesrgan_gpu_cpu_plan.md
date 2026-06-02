# Plano: upscale por Dockerfile dedicado

## Objetivo
Separar o microservico de upscale em imagens dedicadas para CPU, NVIDIA/CUDA e AMD/ROCm.

- `upscale/Dockerfile.cpu` baixa `realesr-general-x4v3.pth` e `realesr-general-wdn-x4v3.pth`.
- `upscale/Dockerfile.nvidia` baixa apenas `4x_NMKD-Siax_200k.pth`.
- `upscale/Dockerfile.amd` baixa apenas `4x_NMKD-Siax_200k.pth`.

## Contrato
- O runtime e definido pela imagem Docker.
- O compose local fica em CPU por padrao.
- Cada imagem carrega somente o modelo esperado para o seu runtime.
- Falhas do Real-ESRGAN caem para Lanczos4, sem tentar trocar de runtime dentro do container.

## Arquivos principais
- `upscale/main.py`
- `upscale/Dockerfile.cpu`
- `upscale/Dockerfile.nvidia`
- `upscale/Dockerfile.amd`
- `docker-compose.yml`
- `docker-compose.example.yml`
- `.env.example`
- `README.md`
- `AGENTS.md`
- `upscale/AGENTS.md`
