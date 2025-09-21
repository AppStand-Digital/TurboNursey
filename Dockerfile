# Dockerfile
FROM ruby:3.4-alpine

# Install build tools and SQLite
RUN apk add --no-cache build-base sqlite sqlite-dev bash

# Set working directory
WORKDIR /app

# Install gems
COPY Gemfile Gemfile.lock* ./
RUN bundle config set without 'development test' && \
    bundle install --jobs 4 --retry 3

# Copy app
COPY views .

# Environment
ENV RACK_ENV=production
ENV PORT=4567

# Expose port
EXPOSE 4567

# Run DB migrations on startup, then start the app with Rack
CMD bundle exec rake db:migrate && bundle exec rackup -p ${PORT} -o 0.0.0.0
