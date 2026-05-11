export const WEB_DEVICE_ID_KEY = 'lexy_web_device_id';

export function generateUUID(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}

export function getOrCreateWebDeviceId(): string {
  let id = localStorage.getItem(WEB_DEVICE_ID_KEY);
  if (!id) {
    id = generateUUID();
    localStorage.setItem(WEB_DEVICE_ID_KEY, id);
  }
  return id;
}

export function getWebDeviceName(): string {
  const ua = navigator.userAgent;
  if (/iPhone/i.test(ua)) return 'iPhone (Web)';
  if (/iPad/i.test(ua)) return 'iPad (Web)';
  if (/Android/i.test(ua)) return 'Android (Web)';
  if (/Mac/i.test(ua)) return 'Mac Browser';
  if (/Win/i.test(ua)) return 'Windows Browser';
  if (/Linux/i.test(ua)) return 'Linux Browser';
  return 'Web Browser';
}
