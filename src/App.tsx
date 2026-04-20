/**
 * App.tsx
 * VitalPath Health Passbook — Main Application Shell
 *
 * Responsibilities:
 *  1. Owns the single `currentView` navigation state.
 *  2. Provides that state (+ dispatcher) via NavContext so deep children
 *     can trigger navigation without prop drilling.
 *  3. Renders the NavBar shell below the active screen.
 *  4. Mounts a global CSS keyframe block (spin animation for the lazy loader).
 *
 * ─── Dependency graph ───────────────────────────────────────────────────────
 *
 *   App
 *   ├── NavContext.Provider          (navigation state broadcast)
 *   ├── <div.app-shell>
 *   │   ├── <div.screen-viewport>   (flex-1, clips active screen)
 *   │   │   └── RenderScreen        (lazy, Suspense-wrapped, from AppRouter)
 *   │   └── <NavBar>                (always visible, 68px, above safe-area)
 *   └── <GlobalStyles />            (injects @keyframes into <head>)
 *
 * ─── Migrating to React Navigation / Expo Router ────────────────────────────
 *  Replace `currentView` + `RenderScreen` with a <Stack.Navigator> or
 *  <Tab.Navigator>. NavContext and NavBar can stay as-is with minor adapter work.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 */

import React, { useState, useEffect } from 'react';
import { View, NavContext, RenderScreen, ROUTES } from './router/AppRouter';
import NavBar from './components/NavBar';

// ─────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────
const DEFAULT_VIEW: View = 'patient-dashboard';

/** LocalStorage key for persisting the last active tab across reloads. */
const PERSIST_KEY = 'vp_active_view';

// ─────────────────────────────────────────────
// APP
// ─────────────────────────────────────────────
export default function App(): React.ReactElement {
  // ── State ──────────────────────────────────
  const [currentView, setCurrentView] = useState<View>(() => {
    // Restore last tab from localStorage so a page refresh doesn't kick
    // the user back to the dashboard unexpectedly.
    const saved = localStorage.getItem(PERSIST_KEY) as View | null;
    const validIds = ROUTES.map((r) => r.id);
    return saved && validIds.includes(saved) ? saved : DEFAULT_VIEW;
  });

  // ── Side-effects ───────────────────────────
  // Persist active tab on every change.
  useEffect(() => {
    localStorage.setItem(PERSIST_KEY, currentView);
  }, [currentView]);

  // Update <title> so the browser tab reflects the active screen.
  useEffect(() => {
    const route = ROUTES.find((r) => r.id === currentView);
    document.title = route
      ? `VitalPath — ${route.label}`
      : 'VitalPath Health Passbook';
  }, [currentView]);

  // ── Navigation handler ─────────────────────
  // Wrapped in useCallback to keep NavContext referentially stable across renders.
  const navigate = React.useCallback((view: View) => {
    setCurrentView(view);
  }, []);

  // ── Render ─────────────────────────────────
  return (
    <NavContext.Provider value={{ currentView, navigate }}>
      {/* Injects global @keyframes used by the lazy-load spinner */}
      <GlobalStyles />

      <div style={styles.shell}>
        {/* ── Screen viewport ── */}
        <div style={styles.viewport}>
          <RenderScreen view={currentView} />
        </div>

        {/* ── Persistent bottom navigation ── */}
        <NavBar
          activeView={currentView}
          onNavigate={navigate}
        />
      </div>
    </NavContext.Provider>
  );
}

// ─────────────────────────────────────────────
// GLOBAL STYLES
// Injects @keyframes that can't live in a React.CSSProperties object.
// A single <style> tag is appended once on mount.
// ─────────────────────────────────────────────
function GlobalStyles(): null {
  useEffect(() => {
    const id = 'vp-global-styles';
    if (document.getElementById(id)) return;

    const tag = document.createElement('style');
    tag.id = id;
    tag.textContent = `
      *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

      html, body, #root {
        height: 100%;
        width: 100%;
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
        -webkit-font-smoothing: antialiased;
        background: #F0F2F8;
        overscroll-behavior: none;
      }

      /* Lazy-loader spinner */
      @keyframes spin {
        from { transform: rotate(0deg); }
        to   { transform: rotate(360deg); }
      }

      /* Prevent iOS tap highlight flicker */
      button { -webkit-tap-highlight-color: transparent; }

      /* Hide scrollbars globally (mobile-first prototype) */
      ::-webkit-scrollbar { display: none; }
      * { scrollbar-width: none; }
    `;
    document.head.appendChild(tag);
  }, []);

  return null;
}

// ─────────────────────────────────────────────
// STYLES
// ─────────────────────────────────────────────
const styles: Record<string, React.CSSProperties> = {
  /**
   * App shell: full-height column.
   * On a real device this would be 100dvh; in the browser prototype
   * it inherits height from #root (set to 100% in GlobalStyles).
   */
  shell: {
    display: 'flex',
    flexDirection: 'column',
    height: '100%',
    width: '100%',
    maxWidth: 430,           // ≈ iPhone 15 Pro Max logical width
    margin: '0 auto',
    overflow: 'hidden',
    boxShadow: '0 0 0 1px rgba(0,0,0,0.06), 0 24px 80px rgba(0,0,0,0.14)',
    background: '#F0F2F8',
    position: 'relative',
  },

  /**
   * Screen viewport: grows to fill all remaining height above the NavBar.
   * overflow:hidden lets individual screens manage their own scroll context.
   */
  viewport: {
    display: 'flex',
    flexDirection: 'column',
    flex: 1,
    overflow: 'hidden',
    position: 'relative',
  },
};
