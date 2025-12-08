# =============================================================================
# STANDALONE SYNC - DOCKERFILE
# =============================================================================
# Purpose: Standalone deployment that clones main Rails app
# Usage: Railway connects to alexatafm/solar-hub-sync (separate repo)
#        This Dockerfile clones the main Rails app for model access
# =============================================================================

FROM ruby:3.3.1-alpine

# Install dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    tzdata \
    bash \
    git

# Clone the main Rails application for model access
# Note: FileroomProjects/solar-hub-simpro is PRIVATE - requires GITHUB_TOKEN
ARG GITHUB_TOKEN
RUN git clone --depth 1 https://${GITHUB_TOKEN}@github.com/FileroomProjects/solar-hub-simpro.git /app

WORKDIR /app

# Install gems from main Rails app
RUN bundle install --without development test

# Copy sync script and CSV from THIS repo (solar-hub-sync)
COPY master_full_sync_v2.rb ./one-time-sync/master_full_sync_v2.rb
COPY hubspot-crm-exports-all-deals-2025-11-28.csv ./one-time-sync/hubspot-crm-exports-all-deals-2025-11-28.csv

# Set environment
ENV TZ=Australia/Melbourne
ENV RAILS_ENV=production
ENV RAILS_LOG_LEVEL=warn
ENV SECRET_KEY_BASE=dummy_secret_for_sync_only

# Make executable
RUN chmod +x one-time-sync/master_full_sync_v2.rb

# Run sync script with Rails context
ENTRYPOINT ["bundle", "exec", "ruby", "one-time-sync/master_full_sync_v2.rb"]
CMD ["--verbose"]

