#!/bin/bash
# Test: CSS-Only Dark Mode Validation
# Validates automatic dark mode based on system preferences

echo "🌙 CSS-Only Dark Mode Test"
echo "=========================="

# Test 1: Server responds
if curl -s http://127.0.0.1:4000 > /dev/null; then
    echo "✅ Jekyll server running at http://127.0.0.1:4000"
else
    echo "❌ Jekyll server not running"
    echo "🔧 Run: cd /Users/yebyen/u/c/cozystack-moon-and-back && ./serve-local.sh"
    exit 1
fi

# Test 2: Dark mode CSS present
if curl -s http://127.0.0.1:4000/assets/css/style.css | grep -q "prefers-color-scheme: dark"; then
    echo "✅ CSS dark mode media query found"
else
    echo "❌ Dark mode CSS missing"
    exit 1
fi

# Test 3: Dark mode styles present
if curl -s http://127.0.0.1:4000/assets/css/style.css | grep -q "background-color: #0d1117"; then
    echo "✅ Dark background color implemented"
else
    echo "❌ Dark background styles missing"
    exit 1
fi

# Test 4: Check HTML loads properly
if curl -s http://127.0.0.1:4000 | grep -q "<title>"; then
    echo "✅ HTML page loads correctly"
else
    echo "❌ HTML page has issues"
    exit 1
fi

echo ""
echo "🎯 AUTOMATIC DARK MODE ACTIVE!"
echo "=============================="
echo ""
echo "🌐 Visit: http://127.0.0.1:4000"
echo ""
echo "💡 Dark mode behavior:"
echo "   - 🌙 Automatically activates if your OS/browser is in dark mode"
echo "   - ☀️ Shows light mode if your system preference is light"
echo "   - 🔄 No toggle needed - respects system preference"
echo ""
echo "🔧 To test both modes:"
echo "   1. Visit the site in your browser"
echo "   2. Change your OS dark mode setting"  
echo "   3. Refresh the page to see the change"
echo ""
echo "✅ All tests passed! CSS-only dark mode is working."