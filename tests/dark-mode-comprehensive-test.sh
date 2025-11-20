#!/bin/bash

echo "=== COMPREHENSIVE DARK MODE TESTS ==="
echo ""

# Test 1: Verify Jekyll is serving our main.scss as main.css
echo "Test 1: CSS File Structure"
echo "✓ Checking if main.scss exists..."
if [ -f "assets/main.scss" ]; then
    echo "  ✅ assets/main.scss exists"
else
    echo "  ❌ assets/main.scss missing"
    exit 1
fi

echo "✓ Checking if Jekyll serves main.css..."
CSS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:4000/assets/main.css)
if [ "$CSS_RESPONSE" = "200" ]; then
    echo "  ✅ main.css served successfully (HTTP 200)"
else
    echo "  ❌ main.css not served (HTTP $CSS_RESPONSE)"
    exit 1
fi

# Test 2: Verify HTML loads the correct CSS file
echo ""
echo "Test 2: HTML CSS Reference"
HTML_CSS_REF=$(curl -s http://127.0.0.1:4000/ | grep -E "href=.*main\.css")
if [[ "$HTML_CSS_REF" == *"main.css"* ]]; then
    echo "  ✅ HTML correctly references main.css"
    echo "    Found: $HTML_CSS_REF"
else
    echo "  ❌ HTML does not reference main.css"
    exit 1
fi

# Test 3: Verify dark mode CSS is present in served file
echo ""
echo "Test 3: Dark Mode CSS Content"
DARK_MODE_RULE=$(curl -s http://127.0.0.1:4000/assets/main.css | grep -o "prefers-color-scheme: dark")
if [ "$DARK_MODE_RULE" = "prefers-color-scheme: dark" ]; then
    echo "  ✅ Dark mode media query present"
else
    echo "  ❌ Dark mode media query missing"
    exit 1
fi

# Test 4: Verify nuclear CSS specificity selectors
echo ""
echo "Test 4: Nuclear CSS Specificity"
NUCLEAR_SELECTORS=$(curl -s http://127.0.0.1:4000/assets/main.css | grep -c "html body")
if [ "$NUCLEAR_SELECTORS" -gt 5 ]; then
    echo "  ✅ Nuclear specificity selectors present ($NUCLEAR_SELECTORS found)"
else
    echo "  ❌ Insufficient nuclear selectors ($NUCLEAR_SELECTORS found, need >5)"
    exit 1
fi

# Test 5: Verify key dark colors are present
echo ""
echo "Test 5: Dark Color Palette"
DARK_BG=$(curl -s http://127.0.0.1:4000/assets/main.css | grep -c "#0d1117")
DARK_HEADER=$(curl -s http://127.0.0.1:4000/assets/main.css | grep -c "#161b22")
LINK_COLOR=$(curl -s http://127.0.0.1:4000/assets/main.css | grep -c "#58a6ff")

if [ "$DARK_BG" -gt 0 ] && [ "$DARK_HEADER" -gt 0 ] && [ "$LINK_COLOR" -gt 0 ]; then
    echo "  ✅ All dark colors present (bg:$DARK_BG, header:$DARK_HEADER, links:$LINK_COLOR)"
else
    echo "  ❌ Missing dark colors (bg:$DARK_BG, header:$DARK_HEADER, links:$LINK_COLOR)"
    exit 1
fi

# Test 6: Verify !important declarations for override power
echo ""
echo "Test 6: CSS Override Power"
IMPORTANT_COUNT=$(curl -s http://127.0.0.1:4000/assets/main.css | grep -c "!important")
if [ "$IMPORTANT_COUNT" -gt 10 ]; then
    echo "  ✅ Sufficient !important declarations ($IMPORTANT_COUNT found)"
else
    echo "  ❌ Insufficient !important declarations ($IMPORTANT_COUNT found, need >10)"
    exit 1
fi

echo ""
echo "=== BROWSER TESTS (Manual) ==="
echo "Run these in your browser's console:"
echo ""
echo "Test 7: Dark Mode Detection"
echo "  window.matchMedia('(prefers-color-scheme: dark)').matches"
echo "  Expected: true (if macOS in dark mode)"
echo ""
echo "Test 8: Applied Background Color"
echo "  getComputedStyle(document.body).backgroundColor"
echo "  Expected: rgb(13, 17, 23) [dark] not rgb(253, 253, 253) [light]"
echo ""
echo "Test 9: Force Dark Mode Test"
echo "  document.body.style.backgroundColor = '#ff0000'"
echo "  Expected: Page turns red (CSS is modifiable)"
echo ""

echo "=== ALL AUTOMATED TESTS PASSED! ✅ ==="
echo ""
echo "If browser tests also pass, dark mode is working correctly."
echo "If page is still bright despite passing tests, try:"
echo "1. Hard refresh: Cmd+Shift+R"
echo "2. Clear browser cache"
echo "3. Check if macOS is actually in dark mode"