#!/bin/bash
# Test: Dark Mode Functionality Validation
# Quick verification that dark mode works locally

echo "🌙 Dark Mode Test Result"
echo "======================="

# Test 1: Server responds
if curl -s http://127.0.0.1:4000 > /dev/null; then
    echo "✅ Jekyll server running at http://127.0.0.1:4000"
else
    echo "❌ Jekyll server not running"
    echo "🔧 Run: cd /Users/yebyen/u/c/cozystack-moon-and-back && ./serve-local.sh"
    exit 1
fi

# Test 2: Dark mode toggle present
if curl -s http://127.0.0.1:4000 | grep -q "theme-toggle"; then
    echo "✅ Dark mode toggle button found"
else
    echo "❌ Dark mode toggle missing"
    exit 1
fi

# Test 3: JavaScript functionality present
if curl -s http://127.0.0.1:4000 | grep -q "localStorage.setItem.*theme"; then
    echo "✅ Dark mode JavaScript functional"
else
    echo "❌ Dark mode JavaScript missing"
    exit 1
fi

# Test 4: CSS variables present
if curl -s http://127.0.0.1:4000/assets/css/style.css | grep -q "data-theme.*dark"; then
    echo "✅ Dark mode CSS variables implemented"
else
    echo "❌ Dark mode CSS missing"
    exit 1
fi

echo ""
echo "🎯 MANUAL TEST REQUIRED:"
echo "========================"
echo "1. 🌐 Open: http://127.0.0.1:4000"
echo "2. 🌙 Click dark mode toggle (top-right corner)"
echo "3. ✨ Verify background turns dark (#0d1117)"
echo "4. 🔄 Refresh page - preference should persist"
echo "5. ☀️ Toggle back to light mode"
echo ""
echo "✅ All automated checks passed!"
echo "🚀 Ready for manual validation"