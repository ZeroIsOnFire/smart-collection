# Smart Collection Catalog

<p align="center">
  <img src="public/logo/logo.png" alt="Smart Collection Catalog logo" width="160">
</p>

[Leia em português](README.pt-BR.md)

Smart Collection Catalog is a private Rails application for cataloging collectible items, with a strong focus on miniature and die-cast cars. It combines manual collection management, local AI-assisted photo preparation, YOLO-based autodetection, wishlist tracking, secure public sharing, and PDF/CSV exports.

## Technology Stack

- **Backend**: Ruby on Rails 8.1.3 and Ruby 3.3.10
- **Database**: MongoDB 7 with Mongoid 9
- **Authentication**: Devise
- **Frontend**: Hotwire (Turbo + Stimulus), Bootstrap 5.3, Bootstrap Icons, Cropper.js, and esbuild
- **Uploads and images**: CarrierWave, MiniMagick, manual crop metadata, JPG conversion, and share-image generation
- **Realtime and jobs**: Action Cable, Redis 7, Sidekiq, and Active Job
- **Local AI**: YOLO11s detection and Real-ESRGAN image upscaling
- **Testing and quality**: RSpec, FactoryBot, RuboCop, rails_best_practices, Flay, Playwright, ESLint, and Bundler Audit
- **Infrastructure**: Docker and Docker Compose

## Main Features

- **Private collections by default**: user-owned data is scoped to the authenticated account.
- **Car catalog**: register brand, name, year, scale, color, tags, observations, photos, crop data, and AI metadata.
- **Initial setup**: first-login preference flow for features such as AI upscaling.
- **AI autodetection**: upload a photo with multiple items, let the local YOLO service detect candidates, and review detected items before saving them.
- **Image preparation**: optional local AI upscaling for car photos, with original/enhanced variants and fallback behavior.
- **Manual cropping**: store crop coordinates and process photos asynchronously.
- **Wishlist**: manage wanted items, priorities, status, photos, public wishlist sharing, and wishlist exports.
- **Secure public sharing**: collections and wishlists are public only when sharing is enabled and accessed through an explicit token.
- **Share images**: generate PNG preview/share assets for cars, public cars, wishlists, and wishlist items.
- **Exports**: generate PDF and CSV reports for collections and wishlists.
- **Admin area**: usage dashboard, user management, and maintenance actions for authorized admins.
- **Realtime UI**: processing states and interface updates use Turbo Streams.

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

3. Create the local Compose file from the official template:

   ```bash
   cp docker-compose.example.yml docker-compose.yml
   ```

4. Review `.env` and choose the `upscale-service` Dockerfile in `docker-compose.yml`:

   - `upscale/Dockerfile.cpu` for the default Docker Desktop path.
   - `upscale/Dockerfile.nvidia` for NVIDIA/CUDA hosts with NVIDIA Container Toolkit.
   - `upscale/Dockerfile.amd` for validated AMD/ROCm Linux environments.
   - `upscale/Dockerfile.vulkan` for experimental Linux Vulkan/ncnn testing.

5. Start the containers:

   ```bash
   docker compose up -d --build
   ```

6. Seed the database:

   ```bash
   docker compose exec web bin/rails db:seed
   ```

7. Open the application:

   ```text
   http://localhost:3000
   ```

## Locale

The application ships with Portuguese (`pt-BR`) and English (`en`) locale files. Portuguese is currently the default runtime locale in `config/initializers/locale.rb`.

## Microservices

The project includes local AI microservices through Docker Compose:

- `yolo-service`: local YOLO11s detection and simple color classification for autodetection flows. See [`yolo/README.md`](yolo/README.md).
- `upscale-service`: local image upscaling/preparation service used by car photo uploads when `IMAGE_UPSCALE_SERVICE_URL` is configured and the user allows AI upscaling. The default setup uses `upscale/Dockerfile.cpu`; see [`upscale/README.md`](upscale/README.md).

Important environment variables:

- `YOLO_SERVICE_URL`: internal YOLO service URL, usually `http://yolo-service:8000`.
- `YOLO_API_KEY`: optional API key sent through `X-API-Key`.
- `IMAGE_UPSCALE_SERVICE_URL`: internal upscale service URL, usually `http://upscale-service:8000`.
- `IMAGE_UPSCALE_API_KEY`: optional API key sent through `X-API-Key`.
- `IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE`: minimum side for car photo preparation, defaulting to `360`.

## Development

Rails, RSpec, RuboCop, and project QA commands should run inside the `web` container:

```bash
docker compose exec web bin/rails routes
docker compose exec web bin/safe_rspec
docker compose exec web bundle exec rubocop
```

Build JavaScript and CSS assets with:

```bash
docker compose exec web npm run build
```

Run focused Playwright tests inside the `web` container:

```bash
docker compose exec web npm run test:e2e -- path/to/test.spec.js --browser=chromium
```

Use `http://127.0.0.1:3000` for browser checks that run from inside the `web` container.

## Repository Guidance

Project-specific agent and quality rules live in [`AGENTS.md`](AGENTS.md). Local skill definitions live in `.skills/`, with minimal agent-specific wrappers under `.codex/skills/` and `.gemini/skills/`.

## License

Smart Collection Catalog is licensed under the GNU Affero General Public License v3.0 or later. See [`LICENSE`](LICENSE).

Copyright (c) 2026 Eli Fachin Junior.

The project name, logo, and visual identity are not licensed for use in a way that suggests an unofficial fork, hosted instance, or derivative is the original project or is endorsed by the author.
