#!/bin/bash
# Quick Jekyll local development server
# Usage: ./serve-local.sh

echo "🚀 Starting Jekyll for CSS-only dark mode testing..."
echo "================================="

# Kill any existing Jekyll processes
pkill -f "jekyll serve" 2>/dev/null || true

# Start Jekyll with local config override
echo "🌐 Server will be available at: http://127.0.0.1:4000"
echo "🌙 Dark mode: Automatic via CSS prefers-color-scheme"
echo "💡 Press Ctrl+C to stop server"
echo ""

# Start server with local config override
bundle exec jekyll serve \
  --config _config.yml,_config-local.yml \
  --host 127.0.0.1 \
  --port 4000 \
  --livereload \
  --incremental \
  --open-url