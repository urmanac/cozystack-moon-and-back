#!/bin/bash
# Test 13: Local Jekyll Dark Mode Validation
# tests/13-local-jekyll-dark-mode.sh

# GIVEN: Jekyll site with dark mode toggle
# WHEN: Site is served locally via bundle exec
# THEN: Dark mode toggle functions correctly

set -euo pipefail

echo "🌙 Testing Local Jekyll Dark Mode Functionality"
echo "=============================================="

# Test 1: Jekyll Dependencies Available
test_jekyll_dependencies() {
  echo "📦 Checking Jekyll dependencies..."
  
  # Check Ruby version (should be >= 2.7)
  ruby_version=$(ruby --version | cut -d' ' -f2 | cut -d'p' -f1)
  echo "Ruby version: $ruby_version"
  
  # Check if bundler is available
  if ! command -v bundle &> /dev/null; then
    echo "❌ Bundler not found. Install with: gem install bundler"
    return 1
  fi
  echo "✅ Bundler available"
  
  return 0
}

# Test 2: Gemfile Setup for Local Development
test_gemfile_setup() {
  echo "💎 Setting up Gemfile for local development..."
  
  # Create Gemfile if it doesn't exist
  if [ ! -f Gemfile ]; then
    cat > Gemfile << 'EOF'
source "https://rubygems.org"

# Jekyll and GitHub Pages
gem "jekyll", "~> 4.3.0"
gem "minima", "~> 2.5"

# GitHub Pages plugins
gem "jekyll-feed", "~> 0.12"
gem "jekyll-sitemap", "~> 1.4"
gem "jekyll-seo-tag", "~> 2.6"

# Local development
gem "webrick", "~> 1.7"  # Required for Ruby 3.0+
gem "logger", "~> 1.4"   # Required for Ruby 3.4+
gem "csv", "~> 3.1"      # Required for Ruby 3.4+
gem "ostruct", "~> 0.3"  # Required for Ruby 3.4+
gem "base64", "~> 0.1"   # Required for Ruby 3.4+

group :jekyll_plugins do
  gem "jekyll-feed"
  gem "jekyll-sitemap" 
  gem "jekyll-seo-tag"
end
EOF
    echo "✅ Created Gemfile for local development"
  else
    echo "✅ Gemfile already exists"
  fi
  
  return 0
}

# Test 3: Bundle Install and Jekyll Build
test_jekyll_build() {
  echo "🔧 Installing dependencies and building site..."
  
  # Install gems
  if ! bundle install --quiet; then
    echo "❌ Bundle install failed"
    return 1
  fi
  echo "✅ Dependencies installed"
  
  # Test Jekyll build
  if ! bundle exec jekyll build --quiet; then
    echo "❌ Jekyll build failed"
    return 1
  fi
  echo "✅ Jekyll build successful"
  
  return 0
}

# Test 4: Start Local Server (Background)
test_start_local_server() {
  echo "🚀 Starting local Jekyll server..."
  
  # Start Jekyll server with baseurl override for local development
  bundle exec jekyll serve --host 127.0.0.1 --port 4000 \
    --baseurl "" --livereload --incremental --force_polling \
    > jekyll.log 2>&1 &
  
  JEKYLL_PID=$!
  echo "Jekyll server PID: $JEKYLL_PID"
  
  # Wait for server to start
  echo "⏳ Waiting for server to start..."
  for i in {1..30}; do
    if curl -s http://127.0.0.1:4000 > /dev/null 2>&1; then
      echo "✅ Jekyll server running at http://127.0.0.1:4000"
      return 0
    fi
    sleep 1
  done
  
  echo "❌ Jekyll server failed to start in 30 seconds"
  echo "📋 Server log:"
  tail -10 jekyll.log || true
  kill $JEKYLL_PID 2>/dev/null || true
  return 1
}

# Test 5: Dark Mode CSS Variables Present
test_dark_mode_css() {
  echo "🎨 Testing dark mode CSS implementation..."
  
  # Check if CSS file is generated
  if [ ! -f "_site/assets/css/style.css" ]; then
    echo "❌ CSS file not generated"
    return 1
  fi
  
  # Check for dark mode variables
  if ! grep -q "data-theme.*dark" "_site/assets/css/style.css"; then
    echo "❌ Dark mode CSS variables not found"
    return 1
  fi
  echo "✅ Dark mode CSS variables present"
  
  # Check for CSS custom properties
  if ! grep -q -- "--bg-color" "_site/assets/css/style.css"; then
    echo "❌ CSS custom properties not found"
    return 1
  fi
  echo "✅ CSS custom properties implemented"
  
  return 0
}

# Test 6: Dark Mode Toggle JavaScript Present
test_dark_mode_javascript() {
  echo "⚡ Testing dark mode JavaScript..."
  
  # Check if home layout includes the toggle
  if [ ! -f "_site/index.html" ]; then
    echo "❌ Site not built - index.html missing"
    return 1
  fi
  
  # Check for toggle button
  if ! grep -q "theme-toggle" "_site/index.html"; then
    echo "❌ Dark mode toggle button not found in HTML"
    return 1
  fi
  echo "✅ Dark mode toggle button present"
  
  # Check for JavaScript functionality
  if ! grep -q "localStorage.setItem.*theme" "_site/index.html"; then
    echo "❌ Dark mode JavaScript not found"
    return 1
  fi
  echo "✅ Dark mode JavaScript implemented"
  
  return 0
}

# Test 7: Manual Dark Mode Validation Instructions
test_manual_validation() {
  echo "👀 Manual validation instructions:"
  echo ""
  echo "🌐 Open: http://127.0.0.1:4000"
  echo "🌙 Click the dark mode toggle (top right)"
  echo "✨ Expected behavior:"
  echo "   - Background changes to dark (#0d1117)"
  echo "   - Text changes to light (#f0f6fc)"
  echo "   - Toggle button shows ☀️ (sun icon)"
  echo "   - Preference persists on page refresh"
  echo ""
  echo "🔧 Debug steps if not working:"
  echo "   1. Check browser console for JavaScript errors"
  echo "   2. Inspect CSS custom properties with DevTools"
  echo "   3. Verify data-theme attribute on <html> element"
  echo "   4. Check localStorage for 'theme' key"
  echo ""
  echo "📝 Development commands:"
  echo "   bundle exec jekyll serve --baseurl='' --livereload  # Local dev (no baseurl)"
  echo "   bundle exec jekyll serve --port 4001                 # Different port"
  echo "   bundle exec jekyll build --baseurl=''               # Generate _site/ locally"
  echo "   bundle exec jekyll clean                            # Clean build artifacts"
  echo ""
  
  return 0
}

# Test 8: Cleanup Function
cleanup_test_environment() {
  echo "🧹 Cleaning up test environment..."
  
  # Kill Jekyll server if running
  if [ ! -z "${JEKYLL_PID:-}" ]; then
    kill $JEKYLL_PID 2>/dev/null || true
    echo "✅ Jekyll server stopped"
  fi
  
  # Optional: Clean build artifacts
  if [ "${CLEAN_BUILD:-false}" = "true" ]; then
    bundle exec jekyll clean 2>/dev/null || true
    echo "✅ Build artifacts cleaned"
  fi
}

# Main test execution
main() {
  echo "🎯 Local Jekyll Dark Mode Test Suite"
  echo "===================================="
  echo ""
  
  # Set trap to cleanup on exit
  trap cleanup_test_environment EXIT
  
  # Run tests in sequence
  test_jekyll_dependencies && \
  test_gemfile_setup && \
  test_jekyll_build && \
  test_start_local_server && \
  test_dark_mode_css && \
  test_dark_mode_javascript && \
  test_manual_validation
  
  local exit_code=$?
  
  if [ $exit_code -eq 0 ]; then
    echo ""
    echo "✅ All automated tests passed!"
    echo "🌙 Ready for manual dark mode validation"
    echo "🌐 Visit: http://127.0.0.1:4000"
    echo ""
    echo "💡 Keep server running for live development"
    echo "   Press Ctrl+C to stop when done"
    echo ""
    
    # Keep server running for manual testing
    wait $JEKYLL_PID 2>/dev/null || true
  else
    echo ""
    echo "❌ Test failed - check output above"
    echo "📋 See jekyll.log for server details"
  fi
  
  return $exit_code
}

# Run main function
main "$@"