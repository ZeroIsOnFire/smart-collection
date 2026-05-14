# AGENTS.md — SCC YOLO Detection Service

## Visão Geral
Este é um microserviço especializado em detecção de objetos utilizando o modelo YOLO11s. Ele foi concebido para rodar localmente (CPU) dentro do ecossistema do Smart Collection Catalog, permitindo a detecção de itens sem dependência obrigatória de APIs externas.

---

## 🛡️ Segurança
A segurança deste serviço é garantida por:
- **Isolamento de Rede**: O serviço não expõe portas para o host; é acessível apenas internamente via rede Docker pelo serviço Rails/Sidekiq.
- **Autenticação via API Key**: Todas as requisições para `/detect` devem incluir o header `X-API-Key` validado contra a variável de ambiente `YOLO_API_KEY`.

---

## Stack Tecnológica
- **Base**: `ultralytics/ultralytics:latest-cpu` (Imagem oficial)
- **Framework API**: FastAPI (Python 3.10+)
- **Modelo**: YOLO11s (Small)
- **Servidor**: Uvicorn

---

## Estrutura de Arquivos
- `main.py`: Lógica da API, carregamento do modelo e autenticação.
- `Dockerfile`: Configuração do container.
- `requirements.txt`: Dependências adicionais (fastapi, uvicorn).

---

## Convenções de Desenvolvimento
- **Manutenção de Modelo**: O modelo `yolo11s.pt` é baixado automaticamente no primeiro boot se não estiver presente.
- **Formato de Resposta**: Sempre retornar coordenadas normalizadas (0.0 a 1.0) no formato de vértices para compatibilidade com o `ImageCropperService` do Rails.
- **Hardware**: Otimizado para execução em CPU. Não assumir presença de CUDA/GPU NVIDIA.
