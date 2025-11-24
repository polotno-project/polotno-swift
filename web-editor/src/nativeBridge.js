const getNativeHandler = () => {
  const handler = window.webkit?.messageHandlers?.editor;
  return typeof handler?.postMessage === 'function' ? handler : null;
};

const loadJsonIntoStore = (store, jsonString) => {
  if (!jsonString) {
    return;
  }

  try {
    const parsed = JSON.parse(jsonString);
    store.loadJSON(parsed);
  } catch (error) {
    console.error('Failed to parse document from native payload', error);
  }
};

export const connectNativeBridge = (store) => {
  window.__polotnoReceiveInitialDoc = (payload) => {
    if (payload) {
      loadJsonIntoStore(store, payload);
    }
  };

  const saveToNative = async () => {
    const docJson = JSON.stringify(store.toJSON());
    const dataUrl = await store.toDataURL({ mimeType: 'image/png' });
    const previewBase64 = dataUrl?.split(',')[1] || '';
    const message = {
      type: 'save',
      docJson,
      previewBase64
    };

    const handler = getNativeHandler();
    if (handler) {
      handler.postMessage(message);
    } else {
      console.info('[PolotnoNativeBridge] payload', message);
      alert('Save payload logged to console (native bridge unavailable).');
    }
  };

  window.polotnoNative = {
    saveToNative
  };

  return { saveToNative };
};


