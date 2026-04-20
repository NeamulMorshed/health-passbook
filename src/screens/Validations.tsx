/**
 * Validations.tsx
 * Thin wrapper — loads the SRS §5 edge-case validation showcase.
 *
 * Full component demos live in: ../../../validations.html
 * Components inside:  §5.2 Duplicate Log modal · §5.4 Timezone prompt · §5.6 Soft toast
 */

import React from 'react';

export default function Validations(): React.ReactElement {
  return (
    <iframe
      src="validations.html"
      title="SRS §5 System Validations"
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
  background: '#1A1D2E',
};
