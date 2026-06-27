# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.3.10
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base

# Rails app lives here
WORKDIR /rails

# Set development environment default
ENV RAILS_ENV="development" \
    BUNDLE_PATH="/usr/local/bundle" \
    PLAYWRIGHT_BROWSERS_PATH="/ms-playwright"


# Throw-away build stage to reduce size of final image
FROM base as build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config libssl-dev libyaml-dev imagemagick nodejs npm

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Install JavaScript packages
COPY package.json package-lock.json ./
RUN npm ci

# Copy application code
COPY . .

# Build JavaScript and CSS assets
RUN npm run build && npm run build:css

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/


# Final stage for app image
FROM base

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl git imagemagick nodejs npm && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Create the app user and install Playwright browser runtime for containerized tests
RUN useradd rails --create-home --shell /bin/bash && \
    npx playwright install --with-deps chromium && \
    mkdir -p public/uploads storage && \
    chown -R rails:rails /usr/local/bundle && \
    chown -R rails:rails /ms-playwright && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    chown -R rails:rails log tmp public/uploads storage
USER rails:rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server"]
