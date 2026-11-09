#!/usr/bin/env bash
set -e

key="$(ruby -I/app/shared/lib -rlab/gem_source -e 'puts Lab::GemSource.from_env.lock_key')"
if [ "$(cat /app/.lab-source 2>/dev/null)" != "$key" ]; then
  rm -f Gemfile.lock
fi
bundle install
echo "$key" > /app/.lab-source
rm -f tmp/pids/server.pid

exec "$@"
