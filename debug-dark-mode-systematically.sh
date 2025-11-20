#!/bin/bash

echo "=== SYSTEMATIC DARK MODE DEBUG ==="
echo ""

echo "1. Testing if your browser detects dark mode..."
echo "   Open browser console and run:"
echo "   window.matchMedia('(prefers-color-scheme: dark)').matches"
echo "   Should return: true"
echo ""

echo "2. Testing if our CSS is being loaded..."
echo "   In browser console, run:"
echo "   getComputedStyle(document.body).backgroundColor"
echo "   Current result: Should be dark if working"
echo ""

echo "3. Force test with browser console:"
echo "   document.body.style.backgroundColor = '#0d1117'"
echo "   document.body.style.color = '#f0f6fc'"
echo "   This should make page dark immediately"
echo ""

echo "4. Check what CSS is actually applied:"
echo "   Right-click on page background -> Inspect"
echo "   Look at Computed styles for body element"
echo "   Check if background-color shows #0d1117 or still light"
echo ""

echo "5. Check CSS media query in DevTools:"
echo "   F12 -> Sources tab -> Open style.css"
echo "   Look for @media (prefers-color-scheme: dark)"
echo "   Should show our nuclear CSS rules"
echo ""

echo "6. Manual CSS override test:"
cat << 'EOF'
   In browser console, paste this entire block:
   
   var style = document.createElement('style');
   style.innerHTML = `
   body, html {
     background-color: #0d1117 !important;
     color: #f0f6fc !important;
   }
   .site-header {
     background-color: #161b22 !important;
   }
   a { color: #58a6ff !important; }
   `;
   document.head.appendChild(style);
EOF

echo ""
echo "If step 6 works but our CSS doesn't, then it's a specificity issue."
echo "If step 6 doesn't work, it might be browser/OS settings."
echo ""

echo "=== CURRENT CSS STATUS ==="
curl -s http://127.0.0.1:4000/assets/css/style.css | grep -A3 "html body," || echo "CSS not found!"