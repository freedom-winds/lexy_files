import { useEffect, useState, useCallback, useRef } from 'react';
import { io } from 'socket.io-client';
import type { Socket } from 'socket.io-client';
import { Layout } from '../components/Layout';
import api, { SOCKET_URL } from '../lib/api';
import { getApiError, formatFileSize } from '../lib/utils';
import {
  Monitor,
  Smartphone,
  Tablet,
  Upload,
  CheckCircle,
  AlertCircle,
  X,
  Wifi,
  ArrowRight,
  Download,
} from 'lucide-react';

interface Device {
  id: number;
  name: string;
  device_type: string;
  platform: string;
  device_id: string;
  is_online: boolean;
}

interface TransferRecord {
  id: number;
  sender_id: number;
  receiver_id: number;
  sender_device_id: number | null;
  receiver_device_id: number | null;
  mode: string;
  status: string;
  file_name: string;
  file_size: number;
  bytes_transferred: number;
  progress_percent: number;
}

const WEB_DEVICE_ID_KEY = 'lexy_web_device_id';
const CHUNK_SIZE = 128 * 1024; // 128 KB
const ACCEPT_TIMEOUT_MS = 120_000;

type PendingAccept = {
  resolve: () => void;
  reject: (reason: Error) => void;
  timeout: number;
};

function DeviceTypeIcon({ type, className }: { type: string; className?: string }) {
  const cls = className ?? 'w-5 h-5 text-indigo-600';
  switch (type.toLowerCase()) {
    case 'phone':
      return <Smartphone className={cls} />;
    case 'tablet':
      return <Tablet className={cls} />;
    case 'laptop':
    case 'desktop':
      return <Monitor className={cls} />;
    default:
      return <Monitor className={cls} />;
  }
}

function downloadBlob(blob: Blob, name: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 5000);
}

export function TransferPage() {
  const webDeviceId = localStorage.getItem(WEB_DEVICE_ID_KEY) ?? '';

  const [devices, setDevices] = useState<Device[]>([]);
  const [myDevice, setMyDevice] = useState<Device | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [sending, setSending] = useState(false);
  const [sendProgress, setSendProgress] = useState(0);
  const [sendTarget, setSendTarget] = useState<string>('');
  const [sendResult, setSendResult] = useState<{ ok: boolean; msg: string } | null>(null);

  // Incoming transfer state
  const [incomingRequest, setIncomingRequest] = useState<TransferRecord | null>(null);
  const [receivingTransfer, setReceivingTransfer] = useState<{
    id: number;
    fileName: string;
    fileSize: number;
    bytesReceived: number;
    chunks: string[];
  } | null>(null);
  const [completedDownloads, setCompletedDownloads] = useState<{ name: string; blob: Blob }[]>([]);

  const socketRef = useRef<Socket | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const pendingAcceptsRef = useRef<Record<number, PendingAccept>>({});

  const rejectPendingAccept = useCallback((transferId: number, message: string) => {
    const pending = pendingAcceptsRef.current[transferId];
    if (!pending) return;
    window.clearTimeout(pending.timeout);
    pending.reject(new Error(message));
    delete pendingAcceptsRef.current[transferId];
  }, []);

  const waitForAccept = useCallback((transferId: number) => {
    return new Promise<void>((resolve, reject) => {
      const timeout = window.setTimeout(() => {
        rejectPendingAccept(transferId, 'Timed out waiting for the receiver to accept.');
      }, ACCEPT_TIMEOUT_MS);
      pendingAcceptsRef.current[transferId] = { resolve, reject, timeout };
    });
  }, [rejectPendingAccept]);

  // Fetch devices
  const fetchDevices = useCallback(async () => {
    try {
      const { data } = await api.get<Device[]>('/devices/');
      const all = Array.isArray(data) ? data : [];
      const self = all.find((d) => d.device_id === webDeviceId) ?? null;
      setMyDevice(self);
      setDevices(all.filter((d) => d.device_id !== webDeviceId));
    } catch (err) {
      setError(getApiError(err));
    } finally {
      setLoading(false);
    }
  }, [webDeviceId]);

  useEffect(() => {
    fetchDevices();
  }, [fetchDevices]);

  // WebSocket connection
  useEffect(() => {
    const token = localStorage.getItem('access_token');
    if (!token || !webDeviceId) return;

    const socket = io(SOCKET_URL, {
      query: { token, device_id: webDeviceId },
      transports: ['websocket', 'polling'],
    });
    socketRef.current = socket;

    // Heartbeat
    const hb = setInterval(() => {
      if (socket.connected) socket.emit('device_heartbeat');
    }, 30_000);

    // Device online/offline updates
    socket.on('device.online', (device: Device) => {
      setDevices((prev) => {
        const exists = prev.find((d) => d.id === device.id);
        if (exists) return prev.map((d) => (d.id === device.id ? { ...d, is_online: true } : d));
        if (device.device_id !== webDeviceId) return [...prev, { ...device, is_online: true }];
        return prev;
      });
    });

    socket.on('device.offline', (device: Device) => {
      setDevices((prev) => prev.map((d) => (d.id === device.id ? { ...d, is_online: false } : d)));
    });

    // Incoming transfer request
    socket.on('transfer.request', (transfer: TransferRecord) => {
      setIncomingRequest(transfer);
    });

    // Transfer accepted — sender side (our send was accepted)
    socket.on('transfer.accepted', (transfer: TransferRecord) => {
      const transferId = transfer.id;
      const pending = pendingAcceptsRef.current[transferId];
      if (!pending) return;
      window.clearTimeout(pending.timeout);
      pending.resolve();
      delete pendingAcceptsRef.current[transferId];
    });

    // Transfer rejected
    socket.on('transfer.rejected', (transfer: TransferRecord) => {
      rejectPendingAccept(transfer.id, `Transfer rejected: ${transfer.file_name}`);
      setSending(false);
      setSendResult({ ok: false, msg: `Transfer rejected: ${transfer.file_name}` });
    });

    // Transfer cancelled
    socket.on('transfer.cancelled', (transfer: TransferRecord) => {
      rejectPendingAccept(transfer.id, 'Transfer was cancelled.');
      setSending(false);
      setReceivingTransfer(null);
      setSendResult({ ok: false, msg: 'Transfer was cancelled.' });
    });

    // Receiving file data chunks
    socket.on('transfer.data', (payload: {
      transfer_id: number;
      chunk: string;
      offset: number;
      bytes_transferred: number;
    }) => {
      setReceivingTransfer((prev) => {
        if (!prev || prev.id !== payload.transfer_id) return prev;
        return {
          ...prev,
          chunks: [...prev.chunks, payload.chunk],
          bytesReceived: payload.bytes_transferred,
        };
      });
    });

    // Transfer progress
    socket.on('transfer.progress', (payload: {
      transfer_id: number;
      bytes_transferred: number;
      file_size: number;
      progress_percent: number;
    }) => {
      // Update send progress
      setSendProgress(payload.progress_percent);
      // Update receive progress
      setReceivingTransfer((prev) => {
        if (!prev || prev.id !== payload.transfer_id) return prev;
        return { ...prev, bytesReceived: payload.bytes_transferred };
      });
    });

    // Transfer complete
    socket.on('transfer.complete', (transfer: TransferRecord) => {
      // If we are the receiver, assemble the file
      setReceivingTransfer((prev) => {
        if (prev && prev.id === transfer.id) {
          // Decode base64 chunks into a Blob
          try {
            const byteArrays = prev.chunks.map((b64) => {
              const binary = atob(b64);
              const bytes = new Uint8Array(binary.length);
              for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
              return bytes;
            });
            const blob = new Blob(byteArrays);
            setCompletedDownloads((c) => [...c, { name: prev.fileName, blob }]);
          } catch {
            // Failed to assemble
          }
          return null;
        }
        return prev;
      });

      // If we are the sender
      setSending(false);
      setSendProgress(100);
      setSendResult({ ok: true, msg: `"${transfer.file_name}" sent successfully!` });
    });

    // Error
    socket.on('transfer.error', (payload: { transfer_id?: number; message: string }) => {
      if (payload.transfer_id) rejectPendingAccept(payload.transfer_id, payload.message);
      setSending(false);
      setSendResult({ ok: false, msg: payload.message });
      setReceivingTransfer(null);
    });

    return () => {
      clearInterval(hb);
      Object.values(pendingAcceptsRef.current).forEach((pending) => {
        window.clearTimeout(pending.timeout);
        pending.reject(new Error('Socket disconnected.'));
      });
      pendingAcceptsRef.current = {};
      socket.disconnect();
      socketRef.current = null;
    };
  }, [rejectPendingAccept, webDeviceId]);

  // Send file to a device
  const handleSendToDevice = async (targetDevice: Device) => {
    if (!selectedFile || !myDevice) return;

    setSending(true);
    setSendProgress(0);
    setSendTarget(targetDevice.name);
    setSendResult(null);

    try {
      // 1. Create transfer via REST API
      const { data: transfer } = await api.post<TransferRecord>('/transfers/', {
        mode: 'same_account',
        target_device_id: targetDevice.id,
        sender_device_id: myDevice.id,
        file_name: selectedFile.name,
        file_size: selectedFile.size,
      });

      // 2. Wait until the receiver explicitly accepts the transfer.
      await waitForAccept(transfer.id);

      // 3. Stream file chunks via WebSocket
      const socket = socketRef.current;
      if (!socket?.connected) {
        setSending(false);
        setSendResult({ ok: false, msg: 'Not connected to server.' });
        return;
      }

      const totalChunks = Math.ceil(selectedFile.size / CHUNK_SIZE);
      for (let i = 0; i < totalChunks; i++) {
        const start = i * CHUNK_SIZE;
        const end = Math.min(start + CHUNK_SIZE, selectedFile.size);
        const slice = selectedFile.slice(start, end);
        const buffer = await slice.arrayBuffer();

        // Convert to base64 for JSON transport
        const bytes = new Uint8Array(buffer);
        let binary = '';
        for (let j = 0; j < bytes.length; j++) binary += String.fromCharCode(bytes[j]);
        const b64 = btoa(binary);

        socket.emit('transfer_data', {
          transfer_id: transfer.id,
          chunk: b64,
          offset: start,
        });

        const pct = Math.round(((i + 1) / totalChunks) * 100);
        setSendProgress(pct);

        // Yield to keep UI responsive
        if (i % 4 === 0) await new Promise<void>((r) => setTimeout(r, 0));
      }

      // 4. Signal completion
      socket.emit('transfer_complete', { transfer_id: transfer.id });
    } catch (err) {
      setSending(false);
      setSendResult({ ok: false, msg: err instanceof Error ? err.message : getApiError(err) });
    }
  };

  // Accept incoming transfer
  const handleAccept = () => {
    if (!incomingRequest || !socketRef.current) return;
    socketRef.current.emit('transfer_accept', { transfer_id: incomingRequest.id });
    setReceivingTransfer({
      id: incomingRequest.id,
      fileName: incomingRequest.file_name,
      fileSize: incomingRequest.file_size,
      bytesReceived: 0,
      chunks: [],
    });
    setIncomingRequest(null);
  };

  // Reject incoming transfer
  const handleReject = () => {
    if (!incomingRequest || !socketRef.current) return;
    socketRef.current.emit('transfer_reject', { transfer_id: incomingRequest.id });
    setIncomingRequest(null);
  };

  const onlineDevices = devices.filter((d) => d.is_online);
  const offlineDevices = devices.filter((d) => !d.is_online);

  return (
    <Layout>
      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-slate-900">Transfer</h1>
          <p className="text-sm text-slate-500 mt-1">
            Send files directly to your other devices in real-time
          </p>
        </div>

        {/* Incoming transfer request */}
        {incomingRequest && (
          <div className="mb-6 p-4 bg-indigo-50 border border-indigo-200 rounded-xl">
            <div className="flex items-start gap-3">
              <Download className="w-5 h-5 text-indigo-600 mt-0.5 shrink-0" />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-slate-900">Incoming transfer</p>
                <p className="text-sm text-slate-600 mt-0.5 truncate">
                  {incomingRequest.file_name}{' '}
                  <span className="text-slate-400">({formatFileSize(incomingRequest.file_size)})</span>
                </p>
                <div className="flex gap-2 mt-3">
                  <button
                    onClick={handleAccept}
                    className="px-3 py-1.5 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium rounded-lg transition-colors"
                  >
                    Accept
                  </button>
                  <button
                    onClick={handleReject}
                    className="px-3 py-1.5 border border-slate-200 bg-white hover:bg-slate-50 text-sm font-medium text-slate-700 rounded-lg transition-colors"
                  >
                    Decline
                  </button>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Receiving transfer progress */}
        {receivingTransfer && (
          <div className="mb-6 p-4 bg-white border border-slate-200 rounded-xl shadow-sm">
            <div className="flex items-center gap-3 mb-2">
              <Download className="w-4 h-4 text-indigo-500 shrink-0" />
              <p className="text-sm font-medium text-slate-800 truncate flex-1">
                Receiving: {receivingTransfer.fileName}
              </p>
              <span className="text-xs text-slate-500 shrink-0">
                {formatFileSize(receivingTransfer.bytesReceived)} / {formatFileSize(receivingTransfer.fileSize)}
              </span>
            </div>
            <div className="w-full bg-slate-100 rounded-full h-2">
              <div
                className="bg-indigo-500 h-2 rounded-full transition-all duration-300"
                style={{
                  width: `${receivingTransfer.fileSize > 0 ? Math.round((receivingTransfer.bytesReceived / receivingTransfer.fileSize) * 100) : 0}%`,
                }}
              />
            </div>
          </div>
        )}

        {/* Completed downloads */}
        {completedDownloads.length > 0 && (
          <div className="mb-6 space-y-2">
            {completedDownloads.map((cd, i) => (
              <div key={i} className="flex items-center gap-3 p-3 bg-emerald-50 border border-emerald-200 rounded-lg">
                <CheckCircle className="w-4 h-4 text-emerald-600 shrink-0" />
                <span className="text-sm text-slate-800 flex-1 truncate">{cd.name}</span>
                <button
                  onClick={() => downloadBlob(cd.blob, cd.name)}
                  className="text-xs font-medium text-emerald-700 hover:text-emerald-900 underline shrink-0"
                >
                  Save
                </button>
              </div>
            ))}
          </div>
        )}

        {/* File picker */}
        <div className="bg-white border border-slate-200 rounded-xl shadow-sm p-5 mb-6">
          <h2 className="text-sm font-semibold text-slate-900 mb-3">Select file to send</h2>
          <input
            ref={fileInputRef}
            type="file"
            className="sr-only"
            onChange={(e) => {
              setSelectedFile(e.target.files?.[0] ?? null);
              setSendResult(null);
            }}
          />
          <div className="flex items-center gap-3">
            <button
              onClick={() => fileInputRef.current?.click()}
              className="inline-flex items-center gap-2 px-4 py-2 border border-slate-200 rounded-lg text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors"
            >
              <Upload className="w-4 h-4" />
              {selectedFile ? 'Change file' : 'Choose file'}
            </button>
            {selectedFile && (
              <div className="flex items-center gap-2 min-w-0">
                <span className="text-sm text-slate-800 truncate max-w-xs">{selectedFile.name}</span>
                <span className="text-xs text-slate-400 shrink-0">
                  ({formatFileSize(selectedFile.size)})
                </span>
                <button
                  onClick={() => {
                    setSelectedFile(null);
                    if (fileInputRef.current) fileInputRef.current.value = '';
                  }}
                  className="p-0.5 rounded text-slate-400 hover:text-slate-600"
                >
                  <X className="w-3.5 h-3.5" />
                </button>
              </div>
            )}
          </div>
        </div>

        {/* Send progress */}
        {sending && (
          <div className="mb-6 p-4 bg-white border border-indigo-200 rounded-xl shadow-sm">
            <div className="flex items-center gap-3 mb-3">
              <ArrowRight className="w-4 h-4 text-indigo-500 shrink-0 animate-pulse" />
              <p className="text-sm font-medium text-slate-800">Sending to {sendTarget}</p>
            </div>
            <div className="w-full bg-slate-100 rounded-full h-2">
              <div
                className="bg-indigo-500 h-2 rounded-full transition-all duration-300"
                style={{ width: `${sendProgress}%` }}
              />
            </div>
            <p className="text-xs text-slate-400 mt-1">{sendProgress}% sent</p>
          </div>
        )}

        {/* Send result */}
        {sendResult && (
          <div
            className={`mb-6 p-3 rounded-lg flex items-center gap-2 ${
              sendResult.ok
                ? 'bg-emerald-50 border border-emerald-200'
                : 'bg-red-50 border border-red-200'
            }`}
          >
            {sendResult.ok ? (
              <CheckCircle className="w-4 h-4 text-emerald-600 shrink-0" />
            ) : (
              <AlertCircle className="w-4 h-4 text-red-600 shrink-0" />
            )}
            <span className={`text-sm ${sendResult.ok ? 'text-slate-800' : 'text-red-700'}`}>
              {sendResult.msg}
            </span>
            <button
              onClick={() => setSendResult(null)}
              className="ml-auto p-0.5 text-slate-400 hover:text-slate-600"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        )}

        {/* Error */}
        {error && (
          <div className="mb-6 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700 flex items-start gap-2">
            <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        {/* Device list */}
        {loading && (
          <div className="flex items-center justify-center py-10">
            <div className="animate-spin rounded-full h-8 w-8 border-2 border-indigo-500 border-t-transparent" />
          </div>
        )}

        {!loading && devices.length === 0 && (
          <div className="text-center py-16">
            <div className="w-16 h-16 rounded-2xl bg-slate-100 flex items-center justify-center mx-auto mb-4">
              <Monitor className="w-8 h-8 text-slate-400" />
            </div>
            <p className="text-sm font-medium text-slate-800 mb-1">No other devices</p>
            <p className="text-sm text-slate-500">
              Register another device on the{' '}
              <a href="/devices" className="text-indigo-600 hover:underline">Devices</a>{' '}
              page to start transferring.
            </p>
          </div>
        )}

        {!loading && onlineDevices.length > 0 && (
          <div className="mb-6">
            <h2 className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">
              Online devices
            </h2>
            <div className="space-y-2">
              {onlineDevices.map((device) => (
                <button
                  key={device.id}
                  onClick={() => handleSendToDevice(device)}
                  disabled={!selectedFile || sending}
                  className="w-full flex items-center gap-4 p-4 bg-white border border-slate-200 rounded-xl shadow-sm hover:border-indigo-300 hover:shadow-md transition-all text-left disabled:opacity-50 disabled:cursor-not-allowed group"
                >
                  <div className="w-10 h-10 rounded-lg bg-indigo-100 flex items-center justify-center shrink-0">
                    <DeviceTypeIcon type={device.device_type} />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium text-slate-800">{device.name}</p>
                    <p className="text-xs text-slate-500 mt-0.5 flex items-center gap-1">
                      <Wifi className="w-3 h-3 text-emerald-500" />
                      <span className="text-emerald-600">Online</span>
                      <span className="text-slate-300">&middot;</span>
                      <span>{device.platform}</span>
                    </p>
                  </div>
                  <ArrowRight className="w-4 h-4 text-slate-300 group-hover:text-indigo-500 transition-colors shrink-0" />
                </button>
              ))}
            </div>
          </div>
        )}

        {!loading && offlineDevices.length > 0 && (
          <div>
            <h2 className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">
              Offline devices
            </h2>
            <div className="space-y-2">
              {offlineDevices.map((device) => (
                <div
                  key={device.id}
                  className="flex items-center gap-4 p-4 bg-white border border-slate-200 rounded-xl shadow-sm opacity-60"
                >
                  <div className="w-10 h-10 rounded-lg bg-slate-100 flex items-center justify-center shrink-0">
                    <DeviceTypeIcon type={device.device_type} className="w-5 h-5 text-slate-400" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium text-slate-600">{device.name}</p>
                    <p className="text-xs text-slate-400 mt-0.5">{device.platform} &middot; Offline</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </Layout>
  );
}
