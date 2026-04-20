/**
 * MedicationManager.tsx
 * Placeholder screen — Medication list, add/edit/refill flows.
 *
 * STATUS: Prototype pending — build order after Doctor Portal is validated.
 * SRS references: §3.1 (quick-log), §4.4 (verified-entry delete guard),
 *                 §5.2 (duplicate-dose detection).
 *
 * Replace this placeholder with the full screen component once built.
 */

import React from 'react';

const PILL_ACCENT = '#5C6FFF';
const SURFACE     = '#FFFFFF';
const BG          = '#F0F2F8';
const TEXT_1      = '#1A1D2E';
const TEXT_3      = '#8A8FA8';

export default function MedicationManager(): React.ReactElement {
  return (
    <div style={styles.root}>
      {/* Top bar */}
      <div style={styles.topBar}>
        <div>
          <div style={styles.eyebrow}>Medication Manager</div>
          <div style={styles.title}>My Medicines</div>
        </div>
        {/* Add button placeholder */}
        <div style={styles.addBtn}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none"
            stroke="white" strokeWidth="2.5" strokeLinecap="round">
            <line x1="12" y1="5" x2="12" y2="19" />
            <line x1="5"  y1="12" x2="19" y2="12" />
          </svg>
        </div>
      </div>

      {/* Coming-soon card */}
      <div style={styles.card}>
        <div style={styles.iconWrap}>
          <svg width="36" height="36" viewBox="0 0 24 24" fill="none"
            stroke={PILL_ACCENT} strokeWidth="1.8" strokeLinecap="round">
            <path d="m10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7Z" />
            <line x1="8.5" y1="8.5" x2="15.5" y2="15.5" />
          </svg>
        </div>
        <div style={styles.cardTitle}>Screen in progress</div>
        <div style={styles.cardBody}>
          Full Medication Manager UI — including schedule list, refill tracker,
          dose history and SRS §5.2 duplicate-detection — will be wired here.
        </div>
        <div style={styles.srsRow}>
          {['§ 3.1', '§ 4.4', '§ 5.2'].map((tag) => (
            <span key={tag} style={styles.srsBadge}>{tag}</span>
          ))}
        </div>
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  root: {
    display: 'flex',
    flexDirection: 'column',
    flex: 1,
    background: BG,
    overflowY: 'auto',
    padding: '0 0 24px',
  },
  topBar: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: '52px 20px 16px',
    background: SURFACE,
    borderBottom: '1px solid #E8EAEF',
  },
  eyebrow: {
    fontSize: 11,
    fontWeight: 600,
    letterSpacing: 1.2,
    textTransform: 'uppercase' as const,
    color: TEXT_3,
    marginBottom: 2,
    fontFamily: 'Inter, sans-serif',
  },
  title: {
    fontSize: 22,
    fontWeight: 800,
    color: TEXT_1,
    fontFamily: 'Inter, sans-serif',
  },
  addBtn: {
    width: 40,
    height: 40,
    borderRadius: 12,
    background: PILL_ACCENT,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
    boxShadow: '0 4px 14px rgba(92,111,255,0.3)',
  },
  card: {
    margin: 20,
    background: SURFACE,
    borderRadius: 20,
    padding: 28,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    textAlign: 'center',
    boxShadow: '0 2px 8px rgba(26,29,46,0.06)',
    gap: 12,
  },
  iconWrap: {
    width: 80,
    height: 80,
    borderRadius: 24,
    background: '#EEF0FF',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 4,
  },
  cardTitle: {
    fontSize: 17,
    fontWeight: 800,
    color: TEXT_1,
    fontFamily: 'Inter, sans-serif',
  },
  cardBody: {
    fontSize: 13,
    color: TEXT_3,
    lineHeight: 1.65,
    fontFamily: 'Inter, sans-serif',
    maxWidth: 280,
  },
  srsRow: {
    display: 'flex',
    gap: 8,
    flexWrap: 'wrap' as const,
    justifyContent: 'center',
    marginTop: 4,
  },
  srsBadge: {
    fontSize: 10,
    fontWeight: 700,
    letterSpacing: 0.8,
    padding: '4px 10px',
    borderRadius: 999,
    background: '#EEF0FF',
    color: PILL_ACCENT,
    border: '1px solid rgba(92,111,255,0.2)',
    fontFamily: 'Inter, sans-serif',
  },
};
