# Smart Collection Catalog

[Leia em portugues](README.pt-BR.md)

Smart Collection Catalog is a premium Rails service for registering and managing private collections, initially focused on die-cast and miniature cars. It supports manual item registration, local AI-assisted photo preparation, YOLO-based autodetection, secure public sharing, and PDF/CSV exports.

## Technologies

- **Backend**: Ruby on Rails 7.1+
- **Database**: MongoDB 7 with Mongoid
- **Authentication**: Devise
- **Frontend**: Hotwire (Turbo + Stimulus) and Bootstrap 5
- **Realtime**: Action Cable through Redis
- **Background jobs**: Sidekiq
- **Local AI**: YOLO11s detection and Real-ESRGAN image upscaling
- **Infrastructure**: Docker and Docker Compose

## Setup

### Requirements

- Docker and Docker Compose

### Installation

1. Clone the repository:

   ```bash
   git clone <repo-url>
   cd smart-collection
   ```

2. Create the environment file from the template:

   ```bash
   cp .env.example .env
   ```

3. Start the containers:

   ```bash
   docker compose up -d --build
   ```

4. Seed the database:

   ```bash
   docker compose exec web bin/rails db:seed
   ```

5. Open the application:

   ```text
   http://localhost:3000
   ```

## Locale

The application ships with Portuguese (`pt-BR`) and English (`en`) locales. Portuguese is currently the default locale in `config/initializers/locale.rb`.

To use the system in English during development, open pages with `?locale=en` when the controller flow supports locale switching, or set the default locale to `:en` in `config/initializers/locale.rb` for an English-first local environment.

## Main Features

- **Private collections by default**: user data remains scoped to the authenticated owner.
- **AI autodetection**: upload a photo with multiple items and let local YOLO detect, crop, and queue items for review.
- **Collection management**: track brand, name, year, scale, color, photos, and metadata for each item.
- **Image preparation**: optional local upscaling prepares photos for final storage and autodetection workflows.
- **Realtime feedback**: processing states and interface updates use Turbo Streams.
- **Secure public sharing**: collections can be shared through an explicit public token only when sharing is enabled.
- **Exports**: generate PDF and CSV reports from the collection.

## Microservices

The project includes local AI microservices that run through Docker Compose:

- `yolo-service`: local YOLO11s detection and simple color classification for autodetection flows. See [`yolo/README.md`](yolo/README.md).
- `upscale-service`: local image upscale/preparation service used by item uploads and autodetection. The default Docker setup uses `upscale/Dockerfile.cpu`; see [`upscale/README.md`](upscale/README.md).

Image preparation thresholds are configured in `.env` with `IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE` for regular item photos and `AUTODETECTION_MINIMUM_SIDE` for autodetection photos.

## Tests

Run the Rails test suite through the safe wrapper:

```bash
docker compose exec web bin/safe_rspec
```

The wrapper validates that the test environment is active before running RSpec.

## License

This is a private-use project. Follow the repository rules in [`AGENTS.md`](AGENTS.md).
