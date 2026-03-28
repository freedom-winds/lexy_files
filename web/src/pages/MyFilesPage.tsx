import { useEffect, useState, useCallback } from 'react';
import { Layout } from '../components/Layout';
import api from '../lib/api';
import { formatFileSize, formatDate, formatRelativeDate, getApiError } from '../lib/utils';
import { FileIcon, Trash2, Copy, Download, Clock, CheckCircle, AlertCircle } from 'lucide-react';

interface UserFile {
  id: number;
  original_filename: string;
  file_size: number;
  mime_type: string;
  pickup_code: string;
  download_count: number;
  status: string;
  expires_at: string;
  created_at: string;
}

interface PaginatedResponse<T> {
  data: T[];
  pagination: { page: number; per_page: number; total: number; pages: number };
}

export function MyFilesPage() {
  const [files, setFiles] = useState<UserFile[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [copiedCode, setCopiedCode] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<number | null>(null);

  const fetchFiles = useCallback(async () => {
    try {
      const { data } = await api.get<PaginatedResponse<UserFile>>('/files');
      setFiles(Array.isArray(data.data) ? data.data : []);
    } catch (err) {
      setError(getApiError(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchFiles();
  }, [fetchFiles]);

  const handleCopy = async (code: string) => {
    try {
      await navigator.clipboard.writeText(code);
      setCopiedCode(code);
      setTimeout(() => setCopiedCode(null), 2000);
    } catch {
      // ignore
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('Delete this file? This action cannot be undone.')) return;
    setDeletingId(id);
    try {
      await api.delete(`/files/${id}`);
      setFiles((prev) => prev.filter((f) => f.id !== id));
    } catch (err) {
      setError(getApiError(err));
    } finally {
      setDeletingId(null);
    }
  };

  const handleDownload = async (file: UserFile) => {
    try {
      const response = await api.get(`/files/download/${file.id}`, {
        responseType: 'blob',
      });
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const a = document.createElement('a');
      a.href = url;
      a.download = file.original_filename;
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      setError(getApiError(err));
    }
  };

  return (
    <Layout>
      <div className="max-w-4xl mx-auto px-4 sm:px-6 py-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-slate-900">My Files</h1>
            <p className="text-sm text-slate-500 mt-1">
              Manage your uploaded files and pickup codes
            </p>
          </div>
          <div className="text-sm text-slate-500">
            {files.length} file{files.length !== 1 ? 's' : ''}
          </div>
        </div>

        {error && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700 flex items-start gap-2">
            <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        {loading && (
          <div className="flex items-center justify-center py-16">
            <div className="animate-spin rounded-full h-8 w-8 border-2 border-indigo-500 border-t-transparent" />
          </div>
        )}

        {!loading && files.length === 0 && !error && (
          <div className="text-center py-16">
            <div className="w-16 h-16 rounded-2xl bg-slate-100 flex items-center justify-center mx-auto mb-4">
              <FileIcon className="w-8 h-8 text-slate-400" />
            </div>
            <p className="text-sm font-medium text-slate-800 mb-1">No files yet</p>
            <p className="text-sm text-slate-500">Upload a file from the home page to get started.</p>
          </div>
        )}

        {!loading && files.length > 0 && (
          <div className="space-y-3">
            {files.map((file) => (
              <div
                key={file.id}
                className={`bg-white rounded-xl border shadow-sm overflow-hidden transition-colors ${
                  file.status !== 'active' ? 'border-slate-200 opacity-60' : 'border-slate-200'
                }`}
              >
                <div className="flex items-start gap-4 p-4 sm:p-5">
                  <div className="w-10 h-10 rounded-lg bg-indigo-100 flex items-center justify-center shrink-0 mt-0.5">
                    <FileIcon className="w-5 h-5 text-indigo-600" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <p className="text-sm font-medium text-slate-800 truncate">
                          {file.original_filename}
                        </p>
                        <p className="text-xs text-slate-500 mt-0.5">
                          {formatFileSize(file.file_size)} &middot; Uploaded {formatDate(file.created_at)}
                        </p>
                      </div>
                      {file.status !== 'active' && (
                        <span className="shrink-0 text-xs font-medium text-red-600 bg-red-50 px-2 py-0.5 rounded-full">
                          Expired
                        </span>
                      )}
                    </div>

                    <div className="flex flex-wrap items-center gap-x-4 gap-y-2 mt-3">
                      {/* Pickup code */}
                      <button
                        onClick={() => handleCopy(file.pickup_code)}
                        className="inline-flex items-center gap-1.5 text-xs font-medium text-indigo-600 hover:text-indigo-700 transition-colors"
                        title="Copy pickup code"
                      >
                        {copiedCode === file.pickup_code ? (
                          <CheckCircle className="w-3.5 h-3.5" />
                        ) : (
                          <Copy className="w-3.5 h-3.5" />
                        )}
                        <span className="font-mono tracking-wider">{file.pickup_code}</span>
                      </button>

                      {/* Downloads */}
                      <span className="inline-flex items-center gap-1 text-xs text-slate-500">
                        <Download className="w-3 h-3" />
                        {file.download_count} download{file.download_count !== 1 ? 's' : ''}
                      </span>

                      {/* Expiry */}
                      <span className="inline-flex items-center gap-1 text-xs text-slate-500">
                        <Clock className="w-3 h-3" />
                        {file.status !== 'active' ? 'Expired' : `Expires ${formatRelativeDate(file.expires_at)}`}
                      </span>
                    </div>
                  </div>

                  <div className="flex items-center gap-1 shrink-0">
                    {file.status === 'active' && (
                      <button
                        onClick={() => handleDownload(file)}
                        className="p-2 rounded-lg text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 transition-colors"
                        title="Download"
                      >
                        <Download className="w-4 h-4" />
                      </button>
                    )}
                    <button
                      onClick={() => handleDelete(file.id)}
                      disabled={deletingId === file.id}
                      className="p-2 rounded-lg text-slate-400 hover:text-red-600 hover:bg-red-50 transition-colors disabled:opacity-50"
                      title="Delete"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </Layout>
  );
}
