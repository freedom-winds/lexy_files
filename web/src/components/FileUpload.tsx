import { useState, useRef } from 'react';
import type { DragEvent, ChangeEvent } from 'react';
import { Upload, CheckCircle, Copy, ExternalLink, X, FileIcon } from 'lucide-react';
import clsx from 'clsx';
import api, { apiUrl } from '../lib/api';
import { useAuth } from '../lib/auth';
import { formatFileSize, getApiError } from '../lib/utils';

interface UploadResult {
  id: number;
  pickup_code: string;
  original_filename: string;
  file_size: number;
}

export function FileUpload() {
  const { ensureAnonymousSession } = useAuth();
  const [isDragging, setIsDragging] = useState(false);
  const [file, setFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [result, setResult] = useState<UploadResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleDragEnter = (e: DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(true);
  };

  const handleDragLeave = (e: DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);
  };

  const handleDragOver = (e: DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
  };

  const handleDrop = (e: DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);
    const dropped = e.dataTransfer.files[0];
    if (dropped) {
      setFile(dropped);
      setResult(null);
      setError(null);
    }
  };

  const handleFileChange = (e: ChangeEvent<HTMLInputElement>) => {
    const selected = e.target.files?.[0];
    if (selected) {
      setFile(selected);
      setResult(null);
      setError(null);
    }
  };

  const handleUpload = async () => {
    if (!file) return;
    setUploading(true);
    setError(null);
    setProgress(0);

    try {
      await ensureAnonymousSession();
      const form = new FormData();
      form.append('file', file);

      const { data } = await api.post<UploadResult>('/files/upload', form, {
        headers: { 'Content-Type': 'multipart/form-data' },
        onUploadProgress: (evt) => {
          if (evt.total) {
            setProgress(Math.round((evt.loaded / evt.total) * 100));
          }
        },
      });
      setResult(data);
    } catch (err) {
      setError(getApiError(err));
    } finally {
      setUploading(false);
    }
  };

  const handleCopy = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // fallback: do nothing
    }
  };

  const handleReset = () => {
    setFile(null);
    setResult(null);
    setError(null);
    setProgress(0);
    if (fileInputRef.current) fileInputRef.current.value = '';
  };

  if (result) {
    return (
      <div className="space-y-4">
        <div className="flex items-center gap-3 p-4 bg-green-50 border border-green-200 rounded-xl">
          <CheckCircle className="w-5 h-5 text-green-600 shrink-0" />
          <div className="min-w-0">
            <p className="text-sm font-medium text-green-800">Upload successful!</p>
            <p className="text-xs text-green-600 truncate">{result.original_filename} &middot; {formatFileSize(result.file_size)}</p>
          </div>
        </div>

        <div className="space-y-2">
          <p className="text-xs font-medium text-slate-500 uppercase tracking-wide">Pickup Code</p>
          <div className="flex items-center gap-2">
            <div className="flex-1 bg-slate-50 border border-slate-200 rounded-lg px-4 py-3">
              <span className="text-2xl font-mono font-bold tracking-widest text-indigo-600">
                {result.pickup_code}
              </span>
            </div>
            <button
              onClick={() => handleCopy(result.pickup_code)}
              className="flex items-center gap-1.5 px-3 py-3 rounded-lg border border-slate-200 bg-white hover:bg-slate-50 text-sm font-medium text-slate-600 transition-colors"
              title="Copy code"
            >
              <Copy className="w-4 h-4" />
              {copied ? 'Copied!' : 'Copy'}
            </button>
          </div>
        </div>

        <a
          href={apiUrl(`/files/download/${result.id}`)}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center justify-center gap-2 w-full py-2.5 rounded-lg border border-indigo-200 bg-indigo-50 text-indigo-700 text-sm font-medium hover:bg-indigo-100 transition-colors"
        >
          <ExternalLink className="w-4 h-4" />
          Direct Download Link
        </a>

        <button
          onClick={handleReset}
          className="w-full py-2.5 rounded-lg border border-slate-200 text-sm font-medium text-slate-600 hover:bg-slate-50 transition-colors"
        >
          Upload Another File
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div
        onDragEnter={handleDragEnter}
        onDragLeave={handleDragLeave}
        onDragOver={handleDragOver}
        onDrop={handleDrop}
        onClick={() => !file && fileInputRef.current?.click()}
        className={clsx(
          'border-2 border-dashed rounded-xl p-8 text-center transition-colors',
          isDragging
            ? 'border-indigo-400 bg-indigo-50'
            : 'border-slate-200 hover:border-indigo-300 hover:bg-slate-50',
          !file && 'cursor-pointer'
        )}
      >
        {file ? (
          <div className="space-y-3">
            <div className="flex items-center justify-center gap-3 p-3 bg-slate-50 rounded-lg border border-slate-200 mx-auto max-w-xs">
              <FileIcon className="w-5 h-5 text-indigo-600 shrink-0" />
              <div className="min-w-0 text-left">
                <p className="text-sm font-medium text-slate-800 truncate">{file.name}</p>
                <p className="text-xs text-slate-500">{formatFileSize(file.size)}</p>
              </div>
              <button
                onClick={(e) => { e.stopPropagation(); handleReset(); }}
                className="ml-auto p-1 rounded hover:bg-slate-200 text-slate-400 hover:text-slate-600 transition-colors"
                aria-label="Remove file"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          </div>
        ) : (
          <div className="space-y-3">
            <div className="w-12 h-12 rounded-full bg-indigo-50 flex items-center justify-center mx-auto">
              <Upload className="w-6 h-6 text-indigo-500" />
            </div>
            <div>
              <p className="text-sm font-medium text-slate-700">
                Drop a file here, or <span className="text-indigo-600">browse</span>
              </p>
              <p className="text-xs text-slate-400 mt-1">Any file type supported</p>
            </div>
          </div>
        )}
      </div>

      <input
        ref={fileInputRef}
        type="file"
        className="hidden"
        onChange={handleFileChange}
        aria-label="File upload input"
      />

      {error && (
        <div className="flex items-start gap-2 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
          <X className="w-4 h-4 mt-0.5 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {uploading && (
        <div className="space-y-1.5">
          <div className="flex justify-between text-xs text-slate-500">
            <span>Uploading...</span>
            <span>{progress}%</span>
          </div>
          <div className="w-full bg-slate-200 rounded-full h-1.5 overflow-hidden">
            <div
              className="bg-indigo-500 h-1.5 rounded-full transition-all duration-300"
              style={{ width: `${progress}%` }}
            />
          </div>
        </div>
      )}

      <button
        onClick={handleUpload}
        disabled={!file || uploading}
        className={clsx(
          'w-full py-2.5 rounded-lg text-sm font-medium transition-colors',
          file && !uploading
            ? 'bg-indigo-600 hover:bg-indigo-700 text-white'
            : 'bg-slate-100 text-slate-400 cursor-not-allowed'
        )}
      >
        {uploading ? 'Uploading...' : 'Upload File'}
      </button>
    </div>
  );
}
