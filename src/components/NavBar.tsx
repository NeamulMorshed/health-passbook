/**
 * NavBar.tsx
 * VitalPath — Bottom Navigation Bar
 *
 * Renders the persistent bottom navigation shell.
 * - Patient routes (Dashboard, Medicines) sit left of the FAB.
 * - Provider route sits right of the FAB.
 * - The debug "SRS §5" tab is hidden in production; set SHOW_DEBUG=true to expose it.
 * - Active state, badge dots, and press-feedback all follow the
 *   Antigravity 100ms contract (transform + opacity, no layout recalc).
 */

import React, { useState } from 'react';
import { View, Route, ROUTES } from '../router/AppRouter';

// ─────────────────────────────────────────────
// CONFIG
// ─────────────────────────────────────────────
const SHOW_DEBUG = true;   // flip to false before shipping to TestFlight / Play Store

// ─────────────────────────────────────────────
// TYPES
// ─────────────────────────────────────────────
interface NavBarProps {
  activeView: View;
  onNavigate: (view: View) => void;
}

// ─────────────────────────────────────────────
// COMPONENT
// ─────────────────────────────────────────────
export default function NavBar({ activeView, onNavigate }: NavBarProps): React.ReactElement {
  const visibleRoutes = ROUTES.filter(
    (r) => r.group !== 'debug' || SHOW_DEBUG
  );

  // Split around the FAB: patient routes left, provider + debug right
  const leftRoutes  = visibleRoutes.filter((r) => r.group === 'patient');
  const rightRoutes = visibleRoutes.filter((r) => r.group !== 'patient');

  return (
    <nav style={styles.bar} role="navigation" aria-label="Main navigation">
      {/* Left cluster */}
      <div style={styles.cluster}>
        {leftRoutes.map((route) => (
          <NavItem
            key={route.id}
            route={route}
            isActive={activeView === route.id}
            onPress={() => onNavigate(route.id)}
          />
        ))}
      </div>

      {/* Centre FAB — quick-log shortcut, always visible */}
      <FAB isActive={false} onPress={() => {/* TODO: open quick-log sheet */}} />

      {/* Right cluster */}
      <div style={styles.cluster}>
        {rightRoutes.map((route) => (
          <NavItem
            key={route.id}
            route={route}
            isActive={activeView === route.id}
            onPress={() => onNavigate(route.id)}
          />
        ))}
      </div>
    </nav>
  );
}

// ─────────────────────────────────────────────
// NAV ITEM
// ─────────────────────────────────────────────
interface NavItemProps {
  route: Route;
  isActive: boolean;
  onPress: () => void;
}

function NavItem({ route, isActive, onPress }: NavItemProps): React.ReactElement {
  const [pressed, setPressed] = useState(false);

  const iconColor  = isActive ? '#5C6FFF' : '#8A8FA8';
  const labelColor = isActive ? '#5C6FFF' : '#8A8FA8';
  const scale      = pressed ? 0.88 : 1;

  return (
    <button
      style={{
        ...styles.navItem,
        transform: `scale(${scale})`,
        background: isActive ? '#EEF0FF' : 'transparent',
      }}
      onClick={onPress}
      onMouseDown={() => setPressed(true)}
      onMouseUp={() => setPressed(false)}
      onMouseLeave={() => setPressed(false)}
      onTouchStart={() => setPressed(true)}
      onTouchEnd={() => { setPressed(false); onPress(); }}
      aria-label={route.label}
      aria-current={isActive ? 'page' : undefined}
    >
      {/* Icon */}
      <div style={{ position: 'relative' }}>
        <svg
          width="22" height="22"
          viewBox="0 0 24 24"
          fill="none"
          stroke={iconColor}
          strokeWidth={isActive ? 2.5 : 2}
          strokeLinecap="round"
          strokeLinejoin="round"
          style={styles.icon}
        >
          {/* Multi-path icons: split on space before 'M' (second path) */}
          {route.iconPath.split(/ (?=M)/).map((d, i) => (
            <path key={i} d={d} />
          ))}
        </svg>

        {/* Badge dot */}
        {route.badge != null && route.badge > 0 && (
          <span style={styles.badge}>{route.badge}</span>
        )}
      </div>

      {/* Label */}
      <span style={{ ...styles.label, color: labelColor }}>
        {route.label}
      </span>
    </button>
  );
}

// ─────────────────────────────────────────────
// FAB
// ─────────────────────────────────────────────
interface FABProps {
  isActive: boolean;
  onPress: () => void;
}

function FAB({ onPress }: FABProps): React.ReactElement {
  const [pressed, setPressed] = useState(false);

  return (
    <button
      style={{
        ...styles.fab,
        transform: pressed ? 'scale(0.91)' : 'scale(1)',
        boxShadow: pressed
          ? '0 2px 8px rgba(61,190,122,0.3)'
          : '0 4px 20px rgba(61,190,122,0.45)',
      }}
      onClick={onPress}
      onMouseDown={() => setPressed(true)}
      onMouseUp={() => setPressed(false)}
      onMouseLeave={() => setPressed(false)}
      onTouchStart={() => setPressed(true)}
      onTouchEnd={() => { setPressed(false); onPress(); }}
      aria-label="Quick log"
    >
      {/* Plus icon */}
      <svg
        width="24" height="24" viewBox="0 0 24 24"
        fill="none" stroke="white" strokeWidth="2.5"
        strokeLinecap="round"
      >
        <line x1="12" y1="5" x2="12" y2="19" />
        <line x1="5"  y1="12" x2="19" y2="12" />
      </svg>
    </button>
  );
}

// ─────────────────────────────────────────────
// STYLES
// All transitions use transform/opacity only — no layout props.
// ─────────────────────────────────────────────
const styles: Record<string, React.CSSProperties> = {
  bar: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    height: 68,
    padding: '0 8px',
    background: '#FFFFFF',
    borderTop: '1px solid #E8EAEF',
    flexShrink: 0,
    // Safe-area padding for notched phones
    paddingBottom: 'env(safe-area-inset-bottom, 0px)',
    position: 'relative',
    zIndex: 10,
  },
  cluster: {
    display: 'flex',
    gap: 4,
    alignItems: 'center',
  },
  navItem: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 3,
    minWidth: 56,
    height: 50,
    borderRadius: 12,
    border: 'none',
    cursor: 'pointer',
    padding: '6px 10px',
    fontFamily: 'Inter, sans-serif',
    transition: 'transform 80ms cubic-bezier(0.4,0,0.2,1), background 150ms cubic-bezier(0.4,0,0.2,1)',
  },
  icon: {
    display: 'block',
    transition: 'stroke 150ms cubic-bezier(0.4,0,0.2,1)',
  },
  label: {
    fontSize: 10,
    fontWeight: 600,
    letterSpacing: 0.2,
    lineHeight: 1,
    fontFamily: 'Inter, sans-serif',
    transition: 'color 150ms cubic-bezier(0.4,0,0.2,1)',
    whiteSpace: 'nowrap',
  },
  badge: {
    position: 'absolute',
    top: -4,
    right: -6,
    minWidth: 16,
    height: 16,
    borderRadius: 8,
    background: '#F03E3E',
    color: 'white',
    fontSize: 9,
    fontWeight: 800,
    fontFamily: 'Inter, sans-serif',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '0 3px',
    border: '2px solid #FFFFFF',
    lineHeight: 1,
  },
  fab: {
    width: 52,
    height: 52,
    borderRadius: '50%',
    background: 'linear-gradient(135deg, #3DBE7A, #35A868)',
    border: 'none',
    cursor: 'pointer',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
    transition: 'transform 80ms cubic-bezier(0.4,0,0.2,1), box-shadow 150ms cubic-bezier(0.4,0,0.2,1)',
  },
};
