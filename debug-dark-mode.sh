#!/bin/bash
# Dark Mode Diagnostic Guide
# Helps debug why dark mode might not be working

echo "🔍 Dark Mode Diagnostic Guide"
echo "============================="

# Test 1: CSS is served correctly
echo ""
echo "1️⃣ CSS VERIFICATION:"
echo "-------------------"
if curl -s http://127.0.0.1:4000/assets/css/style.css | grep -q "prefers-color-scheme: dark"; then
    echo "✅ CSS media query exists"
    echo "📋 Media query found: @media (prefers-color-scheme: dark)"
else
    echo "❌ CSS media query missing"
    exit 1
fi

# Test 2: Dark mode styles are present
echo ""
echo "2️⃣ STYLE VERIFICATION:"
echo "---------------------"
if curl -s http://127.0.0.1:4000/assets/css/style.css | grep -q "#0d1117"; then
    echo "✅ Dark background color present (#0d1117)"
else
    echo "❌ Dark background color missing"
    exit 1
fi

echo ""
echo "3️⃣ BROWSER DEBUGGING STEPS:"
echo "============================="
echo ""
echo "🌐 1. Open http://127.0.0.1:4000 in your browser"
echo ""
echo "🛠️ 2. Open Developer Tools (F12 or Cmd+Option+I)"
echo ""
echo "📋 3. In the Console tab, run this JavaScript:"
echo "   window.matchMedia('(prefers-color-scheme: dark)').matches"
echo ""
echo "   Expected result if macOS is in dark mode: true"
echo "   Expected result if macOS is in light mode: false"
echo ""
echo "🎨 4. Check the Elements tab:"
echo "   - Look for the <body> element"
echo "   - Check if background-color is #0d1117 (dark) or #fdfdfd (light)"
echo ""
echo "🔍 5. In the Elements tab, find the <link> tag for CSS:"
echo "   <link rel=\"stylesheet\" href=\"/assets/css/style.css\">"
echo "   - Click on the href link to view the CSS"
echo "   - Search for 'prefers-color-scheme' in the CSS file"
echo ""
echo "⚡ 6. Force dark mode test (in Console):"
echo "   document.body.style.backgroundColor = '#0d1117'"
echo "   document.body.style.color = '#f0f6fc'"
echo ""
echo "   If this makes it dark, the CSS media query isn't triggering"
echo ""
echo "🔧 7. Check your macOS System Preferences:"
echo "   System Preferences → General → Appearance → Dark"
echo "   (or System Settings → Appearance → Dark on newer macOS)"
echo ""
echo "📱 8. Alternative test - change browser setting:"
echo "   Chrome: DevTools → Settings (gear) → Preferences → Appearance → Dark"
echo "   Safari: Develop → Experimental Features → Dark Mode CSS Support"
echo ""
echo "🚨 COMMON ISSUES:"
echo "================"
echo "❗ Browser doesn't support prefers-color-scheme (very old browsers)"
echo "❗ macOS appearance is 'Auto' instead of 'Dark'"
echo "❗ Browser override settings blocking system preference"
echo "❗ CSS cache - try hard refresh (Cmd+Shift+R)"

echo ""
echo "✅ CSS is properly configured. Check browser console steps above!"