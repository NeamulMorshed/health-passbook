/**
 * DoctorPortal.tsx
 * Thin wrapper — loads the existing doctor-portal.html prototype in a sandboxed
 * iframe. Replace the `src` with a proper React screen when rebuilding in Flutter/RN.
 *
 * Full screen logic lives in: ../../../doctor-portal.html
 * Screens inside:  Roster (s-roster) → Patient Detail (s-patient) → Sync (s-sync)
 */

import React from 'react';

export default function DoctorPortal(): React.ReactElement {
  return (
    <iframe
      src="doctor-portal.html"
      title="Doctor Provider Portal"
      style={iframeStyle}
      sandbox="allow-scripts allow-same-origin"
    />
  );
}

const iframeStyle: React.CSSProperties = {
  width: '100%',
  flex: 1,
  border: 'none',
  display: 'block',
  background: '#F0F2F8',
};
