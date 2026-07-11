# SCC - Serviço de Detecção YOLO

[Read in English](README.md)

Microserviço FastAPI responsável pela detecção local de objetos com YOLO11s e pela classificação simples de cor nos fluxos de autodetecção do Smart Collection Catalog.

## Endpoints

- `GET /health`: retorna o status do serviço.
- `POST /detect`: recebe multipart `file`; retorna objetos detectados com coordenadas de vértices normalizadas.
- `POST /classify`: recebe multipart `file`; retorna o rótulo principal do objeto e a cor detectada.
- `POST /classify_color`: recebe multipart `file`; retorna a classificação de cor dominante.

Quando `YOLO_API_KEY` estiver configurada, envie o header `X-API-Key`.

## Modelo e contrato de saída

- Modelo padrão: `yolo11s.pt`.
- Pode ser alterado com `YOLO_MODEL`.
- O serviço é otimizado para CPU e não deve assumir disponibilidade de GPU.
- Coordenadas retornam em vértices normalizados (`0.0` a `1.0`) no formato esperado pelo Rails.
- O Rails não deve usar o label do YOLO para preencher nome/modelo do item automaticamente. Novos itens detectados usam label genérico traduzido.
- A classificação de cor usa lógica local HSV/K-Means em `main.py`; ela não depende de um segundo modelo de ML.

## Docker Compose

O serviço é construído a partir de `yolo/Dockerfile` e roda na rede interna do Docker. Ele não precisa expor porta para o host.

Exemplo de serviço:

```yaml
yolo-service:
  build:
    context: ./yolo
  environment:
    - YOLO_API_KEY=${YOLO_API_KEY}
  restart: unless-stopped
```

Suba apenas o YOLO:

```bash
docker compose up -d --build yolo-service
```

Dentro do Compose, Rails e Sidekiq devem chamar:

```text
http://yolo-service:8000
```

## Variáveis de ambiente

- `YOLO_API_KEY`: chave opcional exigida pelo header `X-API-Key`.
- `YOLO_MODEL`: caminho/nome do modelo; padrão `yolo11s.pt`.
- `ULTRALYTICS_OFFLINE`: deve permanecer `True` para evitar chamadas de rede em containers isolados.

## Notas de desenvolvimento

- Mantenha o monkeypatch `torch.load(weights_only=False)` antes de importar `ultralytics`; PyTorch 2.6+ quebra a desserialização do modelo sem isso.
- Mantenha coordenadas de saída normalizadas e compatíveis com o cropper do Rails.
- Não adicione dependências Python sem aprovação explícita.
- Se testes forem adicionados, eles não devem baixar modelos nem exigir acesso a GPU.

## Exemplo manual de requisição

```bash
curl -H "X-API-Key: $YOLO_API_KEY" \
  -F "file=@sample.jpg" \
  http://localhost:8000/detect
```

No setup padrão do projeto, chame o serviço a partir do Rails/Sidekiq por `http://yolo-service:8000`, não por uma porta do host.
