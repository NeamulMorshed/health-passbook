/**
 * PatientDashboard.tsx
 * Thin wrapper — loads the existing dashboard.html prototype in a sandboxed
 * iframe. Replace the `src` with a proper React screen when rebuilding in Flutter/RN.
 *
 * Full screen logic lives in: ../../../dashboard.html
 */

import React from 'react';

export default function PatientDashboard(): React.ReactElement {
  return (
    <iframe
      src="dashboard.html"
      title="Patient Dashboard"
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
