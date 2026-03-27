import { useEffect, useState, useCallback } from 'react';
import { Layout } from '../components/Layout';
import api from '../lib/api';
import { getApiError, formatDate } from '../lib/utils';
import {
  Monitor,
  Smartphone,
  Tablet,
  Tv,
  Plus,
  Trash2,
  AlertCircle,
  Wifi,
  WifiOff,
  X,
} from 'lucide-react';

interface Device {
  id: number;
  user_id: number;
  name: string;
  device_type: string;
  platform: string;
  device_id: string;
  is_online: boolean;
  last_seen_at: string | null;
  created_at: string;
}

const WEB_DEVICE_ID_KEY = 'lexy_web_device_id';

function generateUUID(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}

function getOrCreateWebDeviceId(): string {
  let id = localStorage.getItem(WEB_DEVICE_ID_KEY);
  if (!id) {
    id = generateUUID();
    localStorage.setItem(WEB_DEVICE_ID_KEY, id);
  }
  return id;
}

function DeviceTypeIcon({ type }: { type: string }) {
  const cls = 'w-5 h-5 text-indigo-600';
  switch (type.toLowerCase()) {
    case 'mobile':
    case 'phone':
      return <Smartphone className={cls} />;
    case 'tablet':
      return <Tablet className={cls} />;
    case 'tv':
      return <Tv className={cls} />;
    default:
      return <Monitor className={cls} />;
  }
}

interface RegisterModalProps {
  onClose: () => void;
  onRegistered: () => void;
}

function RegisterModal({ onClose, onRegistered }: RegisterModalProps) {
  const [name, setName] = useState('');
  const [deviceType, setDeviceType] = useState('desktop');
  const [platform, setPlatform] = useState('web');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) {
      setError('Device name is required.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      const deviceId = generateUUID();
      await api.post<Device>('/devices', {
        name: name.trim(),
        device_type: deviceType,
        platform,
        device_id: deviceId,
      });
      onRegistered();
    } catch (err) {
      setError(getApiError(err));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
    >
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md p-6">
        <div className="flex items-center justify-between mb-5">
          <h2 id="modal-title" className="text-lg font-semibold text-slate-900">
            Register New Device
          </h2>
          <button
            onClick={onClose}
            className="p-1 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition-colors"
            aria-label="Close modal"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {error && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700 flex items-start gap-2">
            <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="device-name" className="block text-sm font-medium text-slate-700 mb-1">
              Device name
            </label>
            <input
              id="device-name"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="My Laptop"
              className="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
              autoFocus
            />
          </div>

          <div>
            <label htmlFor="device-type" className="block text-sm font-medium text-slate-700 mb-1">
              Device type
            </label>
            <select
              id="device-type"
              value={deviceType}
              onChange={(e) => setDeviceType(e.target.value)}
              className="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
            >
              <option value="desktop">Desktop / Laptop</option>
              <option value="mobile">Mobile</option>
              <option value="tablet">Tablet</option>
              <option value="tv">TV / Set-top box</option>
              <option value="other">Other</option>
            </select>
          </div>

          <div>
            <label htmlFor="platform" className="block text-sm font-medium text-slate-700 mb-1">
              Platform
            </label>
            <select
              id="platform"
              value={platform}
              onChange={(e) => setPlatform(e.target.value)}
              className="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
            >
              <option value="web">Web</option>
              <option value="windows">Windows</option>
              <option value="macos">macOS</option>
              <option value="linux">Linux</option>
              <option value="android">Android</option>
              <option value="ios">iOS</option>
            </select>
          </div>

          <div className="flex gap-3 pt-1">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 border border-slate-200 rounded-lg text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={submitting}
              className="flex-1 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 disabled:opacity-60 text-white rounded-lg text-sm font-medium transition-colors"
            >
              {submitting ? 'Registering...' : 'Register device'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}

export function DevicesPage() {
  const [devices, setDevices] = useState<Device[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showModal, setShowModal] = useState(false);
  const [deletingId, setDeletingId] = useState<number | null>(null);
  const [autoRegisterDone, setAutoRegisterDone] = useState(false);

  const webDeviceId = getOrCreateWebDeviceId();

  const fetchDevices = useCallback(async () => {
    try {
      const { data } = await api.get<Device[]>('/devices');
      setDevices(Array.isArray(data) ? data : []);
    } catch (err) {
      setError(getApiError(err));
    } finally {
      setLoading(false);
    }
  }, []);

  // Auto-register the current browser as a device on first visit
  const autoRegisterBrowser = useCallback(async () => {
    if (autoRegisterDone) return;
    setAutoRegisterDone(true);
    try {
      const { data: existingDevices } = await api.get<Device[]>('/devices');
      const alreadyRegistered = existingDevices.some((d) => d.device_id === webDeviceId);
      if (!alreadyRegistered) {
        const name = (() => {
          const ua = navigator.userAgent;
          if (/iPhone/i.test(ua)) return 'iPhone (Web)';
          if (/iPad/i.test(ua)) return 'iPad (Web)';
          if (/Android/i.test(ua)) return 'Android (Web)';
          if (/Mac/i.test(ua)) return 'Mac Browser';
          if (/Win/i.test(ua)) return 'Windows Browser';
          if (/Linux/i.test(ua)) return 'Linux Browser';
          return 'Web Browser';
        })();
        await api.post<Device>('/devices', {
          name,
          device_type: 'desktop',
          platform: 'web',
          device_id: webDeviceId,
        });
      }
      setDevices(Array.isArray(existingDevices) ? existingDevices : []);
    } catch {
      // Non-fatal: silently fall back to fetching without auto-register
    } finally {
      await fetchDevices();
    }
  }, [autoRegisterDone, webDeviceId, fetchDevices]);

  useEffect(() => {
    autoRegisterBrowser();
  }, [autoRegisterBrowser]);

  const handleDelete = async (id: number) => {
    const device = devices.find((d) => d.id === id);
    const isSelf = device?.device_id === webDeviceId;
    const confirmMsg = isSelf
      ? 'Remove this browser from your devices? You can re-register it by revisiting this page.'
      : `Remove "${device?.name ?? 'this device'}"? This cannot be undone.`;
    if (!confirm(confirmMsg)) return;

    setDeletingId(id);
    try {
      await api.delete(`/devices/${id}`);
      setDevices((prev) => prev.filter((d) => d.id !== id));
      if (isSelf) {
        // Clear stored device id so it gets regenerated on next visit
        localStorage.removeItem(WEB_DEVICE_ID_KEY);
      }
    } catch (err) {
      setError(getApiError(err));
    } finally {
      setDeletingId(null);
    }
  };

  const handleRegistered = async () => {
    setShowModal(false);
    setLoading(true);
    await fetchDevices();
  };

  return (
    <Layout>
      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Devices</h1>
            <p className="text-sm text-slate-500 mt-1">
              Devices registered to your account for file transfers
            </p>
          </div>
          <button
            onClick={() => setShowModal(true)}
            className="inline-flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium rounded-lg transition-colors"
          >
            <Plus className="w-4 h-4" />
            <span className="hidden sm:inline">Add device</span>
            <span className="sm:hidden">Add</span>
          </button>
        </div>

        {error && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700 flex items-start gap-2">
            <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
            <span>{error}</span>
            <button
              onClick={() => setError(null)}
              className="ml-auto text-red-400 hover:text-red-600"
              aria-label="Dismiss error"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        )}

        {loading && (
          <div className="flex items-center justify-center py-16">
            <div className="animate-spin rounded-full h-8 w-8 border-2 border-indigo-500 border-t-transparent" />
          </div>
        )}

        {!loading && devices.length === 0 && !error && (
          <div className="text-center py-16">
            <div className="w-16 h-16 rounded-2xl bg-slate-100 flex items-center justify-center mx-auto mb-4">
              <Monitor className="w-8 h-8 text-slate-400" />
            </div>
            <p className="text-sm font-medium text-slate-800 mb-1">No devices registered</p>
            <p className="text-sm text-slate-500">
              Add a device to start transferring files between your devices.
            </p>
          </div>
        )}

        {!loading && devices.length > 0 && (
          <div className="space-y-3">
            {devices.map((device) => {
              const isSelf = device.device_id === webDeviceId;
              return (
                <div
                  key={device.id}
                  className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden"
                >
                  <div className="flex items-center gap-4 p-4 sm:p-5">
                    <div className="w-10 h-10 rounded-lg bg-indigo-100 flex items-center justify-center shrink-0">
                      <DeviceTypeIcon type={device.device_type} />
                    </div>

                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2 flex-wrap">
                        <p className="text-sm font-medium text-slate-800">
                          {device.name}
                        </p>
                        {isSelf && (
                          <span className="text-xs font-medium text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded-full">
                            This browser
                          </span>
                        )}
                        <span
                          className="inline-flex items-center gap-1 text-xs font-medium"
                          aria-label={device.is_online ? 'Online' : 'Offline'}
                        >
                          {device.is_online ? (
                            <>
                              <Wifi className="w-3 h-3 text-emerald-500" />
                              <span className="text-emerald-600">Online</span>
                            </>
                          ) : (
                            <>
                              <WifiOff className="w-3 h-3 text-slate-400" />
                              <span className="text-slate-400">Offline</span>
                            </>
                          )}
                        </span>
                      </div>
                      <p className="text-xs text-slate-500 mt-0.5">
                        {device.platform} &middot; {device.device_type}
                        {device.last_seen_at
                          ? ` \u00b7 Last seen ${formatDate(device.last_seen_at)}`
                          : ` \u00b7 Registered ${formatDate(device.created_at)}`}
                      </p>
                    </div>

                    <button
                      onClick={() => handleDelete(device.id)}
                      disabled={deletingId === device.id}
                      className="p-2 rounded-lg text-slate-400 hover:text-red-600 hover:bg-red-50 transition-colors disabled:opacity-50 shrink-0"
                      aria-label={`Remove ${device.name}`}
                      title="Remove device"
                    >
                      {deletingId === device.id ? (
                        <div className="animate-spin rounded-full h-4 w-4 border-2 border-red-400 border-t-transparent" />
                      ) : (
                        <Trash2 className="w-4 h-4" />
                      )}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {showModal && (
        <RegisterModal
          onClose={() => setShowModal(false)}
          onRegistered={handleRegistered}
        />
      )}
    </Layout>
  );
}
