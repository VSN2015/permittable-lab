FROM ruby:3.3-slim-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential git pkg-config libyaml-dev libpq-dev curl chromium fonts-liberation \
 && rm -rf /var/lib/apt/lists/*

ENV BUNDLE_PATH=/bundle \
    BROWSER_PATH=/usr/bin/chromium

WORKDIR /app

ENTRYPOINT ["/app/shared/bin/entrypoint.sh"]
