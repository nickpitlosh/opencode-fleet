# Domain: Web Frontend (HTML, CSS, JavaScript)

Create a complete single-page application that implements a real-time collaborative text editor. Requirements:
1. Semantic HTML5 structure with proper ARIA labels
2. CSS Grid/Flexbox layout with dark/light theme toggle via CSS custom properties
3. Vanilla JavaScript — no frameworks. Implement:
   - Operational Transformation for conflict resolution
   - WebSocket simulation (mock the server with a BroadcastChannel)
   - Cursor position sync between "users"
   - Debounced localStorage persistence
4. Responsive design: mobile-first, breakpoints at 640px, 1024px
5. Include a working package.json with an ES module build script
6. Write 3 unit tests using Node's built-in test runner

Deliver: index.html, styles.css, editor.js, ot-engine.js, package.json, tests/editor.test.js
