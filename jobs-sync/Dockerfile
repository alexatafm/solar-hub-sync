# Use official Ruby 3.3.1 image
FROM ruby:3.3.1-slim

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

# Copy application code
COPY sync_jobs.rb ./
COPY test_sync.rb ./
COPY debug_sync.rb ./
COPY debug_gross_margin.rb ./

# Create directory for logs and reports
RUN mkdir -p /app/logs

# Set environment variables for production
ENV RAILS_ENV=production \
    RACK_ENV=production

# Default command - run the sync
CMD ["ruby", "sync_jobs.rb"]

