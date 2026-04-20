/**
 * AppRouter.tsx
 * VitalPath — Navigation Router
 *
 * Defines every navigable view in the app, the sidebar/bottom-nav route manifest,
 * and the pure render function that maps the active View → its screen component.
 *
 * No external router library required — the prototype uses a simple React.useState
 * dispatch pattern. Swap `renderScreen()` for <Routes> when migrating to
 * react-router-dom v6 or Expo Router.
 */

import React, { Suspense, lazy } from 'react';

// ─────────────────────────────────────────────
// 1. VIEW ENUM
// Add a new entry here whenever a new screen is built.
// ─────────────────────────────────────────────
export type View =
  | 'patient-dashboard'
  | 'medication-manager'
  | 'doctor-portal'
  | 'validations';          // SRS §5 edge-case showcase

// ─────────────────────────────────────────────
// 2. ROUTE MANIFEST
// Drives both NavBar rendering and the screen switch.
// `group` separates patient-facing vs. provider-facing nav items.
// ─────────────────────────────────────────────
export interface Route {
  id: View;
  label: string;
  group: 'patient' | 'doctor' | 'debug';
  /** Inline SVG path data — keeps the manifest dependency-free */
  iconPath: string;
  /** Optional: badge count for notification dots */
  badge?: number;
}

export const ROUTES: Route[] = [
  {
    id: 'patient-dashboard',
    label: 'Dashboard',
    group: 'patient',
    iconPath:
      'M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z M9 22V12h6v10',
  },
  {
    id: 'medication-manager',
    label: 'Medicines',
    group: 'patient',
    iconPath:
      'm10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7Z M8.5 8.5l7 7',
    badge: 2,               // e.g. 2 doses due
  },
  {
    id: 'doctor-portal',
    label: 'Provider',
    group: 'doctor',
    iconPath:
      'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2 M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M16 3.13a4 4 0 0 1 0 7.75',
  },
  {
    id: 'validations',
    label: 'SRS §5',
    group: 'debug',
    iconPath:
      'M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z M12 9v4 M12 17h.01',
  },
];

// ─────────────────────────────────────────────
// 3. LAZY SCREEN IMPORTS
// Each screen is a thin iframe wrapper around the existing HTML prototype.
// Code-split so only the active screen is evaluated.
// ─────────────────────────────────────────────
const PatientDashboard  = lazy(() => import('../screens/PatientDashboard'));
const MedicationManager = lazy(() => import('../screens/MedicationManager'));
const DoctorPortal      = lazy(() => import('../screens/DoctorPortal'));
const Validations       = lazy(() => import('../screens/Validations'));

const SCREEN_MAP: Record<View, React.LazyExoticComponent<React.FC>> = {
  'patient-dashboard':  PatientDashboard,
  'medication-manager': MedicationManager,
  'doctor-portal':      DoctorPortal,
  'validations':        Validations,
};

// ─────────────────────────────────────────────
// 4. RENDER FUNCTION
// Called by App.tsx — returns the active screen wrapped in a
// Suspense boundary so lazy loading never blocks the shell.
// ─────────────────────────────────────────────
interface RenderScreenProps {
  view: View;
}

export function RenderScreen({ view }: RenderScreenProps): React.ReactElement {
  const ActiveScreen = SCREEN_MAP[view];
  return (
    <Suspense fallback={<ScreenLoader />}>
      <ActiveScreen />
    </Suspense>
  );
}

// ─────────────────────────────────────────────
// 5. FALLBACK LOADER
// Shown while the lazy screen chunk is fetching.
// Mirrors the VitalPath design token palette.
// ─────────────────────────────────────────────
function ScreenLoader(): React.ReactElement {
  return (
    <div style={styles.loader}>
      <svg
        width="40" height="40" viewBox="0 0 24 24"
        fill="none" stroke="#5C6FFF" strokeWidth="2.5"
        strokeLinecap="round" strokeLinejoin="round"
        style={styles.loaderSpinner}
      >
        <path d="M21 12a9 9 0 1 1-6.219-8.56" />
      </svg>
      <span style={styles.loaderText}>Loading…</span>
    </div>
  );
}

// ─────────────────────────────────────────────
// 6. NAVIGATION CONTEXT
// Allows deep-nested components (e.g. a "Go to Doctor Portal" CTA
// inside the Dashboard) to trigger top-level navigation without
// prop-drilling through every intermediate component.
// ─────────────────────────────────────────────
interface NavContextValue {
  currentView: View;
  navigate: (view: View) => void;
}

export const NavContext = React.createContext<NavContextValue>({
  currentView: 'patient-dashboard',
  navigate: () => {},
});

export const useNav = (): NavContextValue => React.useContext(NavContext);

// ─────────────────────────────────────────────
// Styles (inline — matches CSS custom properties in HTML prototypes)
// ─────────────────────────────────────────────
const styles: Record<string, React.CSSProperties> = {
  loader: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    flex: 1,
    height: '100%',
    gap: 12,
    background: '#F0F2F8',
  },
  loaderSpinner: {
    animation: 'spin 0.9s linear infinite',
  },
  loaderText: {
    fontFamily: 'Inter, sans-serif',
    fontSize: 13,
    fontWeight: 600,
    color: '#8A8FA8',
    letterSpacing: 0.3,
  },
};
