import { useEffect, useMemo, useState } from 'react';
import { createStore } from 'polotno/model/store';
import { PolotnoContainer, SidePanelWrap, WorkspaceWrap } from 'polotno';
import { Workspace } from 'polotno/canvas/workspace';
import { Toolbar } from 'polotno/toolbar/toolbar';
import { ZoomButtons } from 'polotno/toolbar/zoom-buttons';
import { SidePanel } from 'polotno/side-panel';
import { connectNativeBridge } from './nativeBridge';

const store = createStore({
  key: 'YOUR_API_KEY',
  showCredit: true,
});

export default function App() {
  const [bridge, setBridge] = useState(null);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    console.log('[EmbeddedEditor] React app mounted');
    const bridgeInstance = connectNativeBridge(store);
    console.log('[EmbeddedEditor] Native bridge ready');
    setBridge(bridgeInstance);
  }, [store]);

  const handleSave = async () => {
    if (!bridge) return;
    setIsSaving(true);
    try {
      await bridge.saveToNative();
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="app-shell">
      <PolotnoContainer className="polotno-editor">
        <SidePanelWrap>
          <SidePanel store={store} />
        </SidePanelWrap>
        <WorkspaceWrap>
          <Toolbar store={store} />
          <Workspace store={store} />
          <ZoomButtons store={store} />
          <div className="bottom-bar">
            <button
              className="primary"
              disabled={!bridge || isSaving}
              onClick={handleSave}
            >
              {isSaving ? 'Saving…' : 'Save & Close'}
            </button>
          </div>
        </WorkspaceWrap>
        {!bridge && <div className="editor-loading">Initializing editor…</div>}
      </PolotnoContainer>
    </div>
  );
}
