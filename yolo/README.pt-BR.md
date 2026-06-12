# SCC - Servico de Deteccao YOLO

[Read in English](README.md)

Microservico FastAPI responsavel pela deteccao local de veiculos e classificacao simples de cor para o fluxo de autodeteccao do Smart Collection Catalog.

## Endpoints HTTP

- `GET /health`: retorna status e modelo carregado.
- `POST /detect`: recebe multipart `file` e retorna deteccoes com `label`, `score`, `vertices` normalizados e `color`.
- `POST /classify_color`: recebe multipart `file` e retorna somente a cor detectada.
- `POST /classify`: recebe multipart `file` e retorna label de veiculo e cor.

Quando `YOLO_API_KEY` estiver configurada, envie o header `X-API-Key`.

## Modelo e Deteccao

- Modelo padrao: `yolo11s.pt`.
- Pode ser alterado com `YOLO_MODEL`.
- O servico usa classes de veiculos do COCO (`1..8`) para deteccao/classificacao.
- Coordenadas retornam em vertices normalizados (`0.0` a `1.0`) no formato esperado pelo Rails.
- O servico foi pensado para CPU local; nao assuma CUDA/GPU.

## Docker Compose

O servico e construido a partir de `yolo/Dockerfile` e roda internamente na rede Docker. Ele nao precisa expor porta para o host.

Servico tipico no `docker-compose.yml`:

```yaml
yolo-service:
  build:
    context: ./yolo
  environment:
    - YOLO_API_KEY=${YOLO_API_KEY}
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
```

Subir apenas o YOLO:

```sh
docker compose up -d --build yolo-service
```

Ver logs:

```sh
docker compose logs --tail=80 yolo-service
```

## Variaveis de Ambiente

- `YOLO_API_KEY`: chave opcional exigida no header `X-API-Key`.
- `YOLO_MODEL`: caminho/nome do modelo; padrao `yolo11s.pt`.
- `ULTRALYTICS_OFFLINE=True`: obrigatoria para evitar chamadas de rede/analytics do Ultralytics no container.

## Deteccao de Cor

A cor nao usa um modelo adicional. A classe `ColorDetector`:

- reduz a imagem para acelerar o processamento;
- usa a area central do crop para evitar fundo;
- converte para HSV;
- filtra sombras e reflexos;
- aplica K-Means;
- classifica em nomes simples como `Vermelho`, `Azul`, `Preto`, `Branco`, `Prata`, `Cinza`, `Dourado`, etc.

## Cuidados

- O monkeypatch de `torch.load(weights_only=False)` precisa acontecer antes de importar `ultralytics`, por causa do PyTorch 2.6+.
- O container deve rodar com `ULTRALYTICS_OFFLINE=True`.
- O Rails nao deve usar o label do YOLO para preencher nome/modelo do item automaticamente; novos itens detectados usam label generico traduzido.

## Teste Manual

Com o servico em execucao e uma imagem local:

```sh
curl -H "X-API-Key: $YOLO_API_KEY" \
  -F "file=@/caminho/para/imagem.jpg" \
  http://localhost:8000/detect
```

Dentro do Compose, os containers Rails e Sidekiq devem chamar `http://yolo-service:8000`.
