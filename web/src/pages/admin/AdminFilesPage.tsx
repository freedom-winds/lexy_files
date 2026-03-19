import { useEffect, useState, useCallback } from 'react';
import api from '../../lib/api';
import { formatFileSize, formatDate, getApiError } from '../../lib/utils';
import { Search, Trash2, Download, Clock, ChevronLeft, ChevronRight, AlertCircle } from 'lucide-react';

interface AdminFile {
  id: number;
  original_filename: string;
  file_size: number;
  mime_type: string;
  pickup_code: string;
  uploader_id: number;
  uploader_username: string | null;
  download_count: number;
  expires_at: string;
  is_expired: boolean;
  created_at: string;
}

interface Pagination {
  page: number;
  per_page: number;
  total: number;
  pages: number;
}

interface FilesResponse {
  data: AdminFile[];
  pagination: Pagination;
}

export function AdminFilesPage() {
  const [files, setFiles] = useState<AdminFile[]>([]);
  const [pagination, setPagination] = useState<Pagination>({ page: 1, per_page: 20, total: 0, pages: 0 });
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionLoading, setActionLoading] = useState<number | null>(null);

  const fetchFiles = useCallback(async (page = 1, q = '') => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams({ page: String(page), per_page: '20' });
      if (q) params.set('q', q);
      const { data } = await api.get<FilesResponse>(`/admin/files?${params}`);
      setFiles(data.data);
      setPagination(data.pagination);
    } catch (err) {
      setError(getApiError(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchFiles();
  }, [fetchFiles]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    fetchFiles(1, search);
  };

  const handleExpire = async (file: AdminFile) => {
    setActionLoading(file.id);
    try {
      await api.put(`/admin/files/${file.id}/expire`);
      setFiles((prev) =>
        prev.map((f) => (f.id === file.id ? { ...f, is_expired: true } : f))
      );
    } catch (err) {
      setError(getApiError(err));
    } finally {
      setActionLoading(null);
    }
  };

  const handleDelete = async (file: AdminFile) => {
    if (!confirm(`Delete "${file.original_filename}"? This cannot be undone.`)) return;
    setActionLoading(file.id);
    try {
      await api.delete(`/admin/files/${file.id}`);
      setFiles((prev) => prev.filter((f) => f.id !== file.id));
      setPagination((prev) => ({ ...prev, total: prev.total - 1 }));
    } catch (err) {
      setError(getApiError(err));
    } finally {
      setActionLoading(null);
    }
  };

  const handleDownload = async (file: AdminFile) => {
    try {
      const response = await api.get(`/admin/files/${file.id}/download`, {
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
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold text-slate-900">Files</h2>
        <span className="text-sm text-slate-500">{pagination.total} total</span>
      </div>

      <form onSubmit={handleSearch} className="flex gap-2">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by filename or pickup code..."
            className="w-full border border-slate-200 rounded-lg pl-9 pr-3 py-2 text-sm text-slate-800 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:border-transparent"
          />
        </div>
        <button
          type="submit"
          className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium rounded-lg transition-colors"
        >
          Search
        </button>
      </form>

      {error && (
        <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700 flex items-start gap-2">
          <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-8 w-8 border-2 border-indigo-500 border-t-transparent" />
        </div>
      ) : (
        <>
          <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="bg-slate-50 border-b border-slate-200">
                    <th className="text-left px-4 py-3 font-medium text-slate-600">File</th>
                    <th className="text-left px-4 py-3 font-medium text-slate-600">Code</th>
                    <th className="text-left px-4 py-3 font-medium text-slate-600">Uploader</th>
                    <th className="text-left px-4 py-3 font-medium text-slate-600">Size</th>
                    <th className="text-left px-4 py-3 font-medium text-slate-600">Status</th>
                    <th className="text-right px-4 py-3 font-medium text-slate-600">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {files.map((file) => (
                    <tr key={file.id} className="hover:bg-slate-50 transition-colors">
                      <td className="px-4 py-3">
                        <div>
                          <p className="font-medium text-slate-800 truncate max-w-[200px]">
                            {file.original_filename}
                          </p>
                          <p className="text-xs text-slate-500">{formatDate(file.created_at)}</p>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <span className="font-mono text-xs tracking-wider text-indigo-600">
                          {file.pickup_code}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-xs text-slate-600">
                        {file.uploader_username || `User #${file.uploader_id}`}
                      </td>
                      <td className="px-4 py-3 text-xs text-slate-600">
                        {formatFileSize(file.file_size)}
                      </td>
                      <td className="px-4 py-3">
                        {file.is_expired ? (
                          <span className="text-xs font-medium text-red-600 bg-red-50 px-2 py-0.5 rounded-full">
                            Expired
                          </span>
                        ) : (
                          <span className="text-xs font-medium text-green-600 bg-green-50 px-2 py-0.5 rounded-full">
                            Active
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3">
                        <div className="flex items-center justify-end gap-1">
                          <button
                            onClick={() => handleDownload(file)}
                            disabled={actionLoading === file.id}
                            className="p-1.5 rounded text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 transition-colors disabled:opacity-50"
                            title="Download"
                          >
                            <Download className="w-3.5 h-3.5" />
                          </button>
                          {!file.is_expired && (
                            <button
                              onClick={() => handleExpire(file)}
                              disabled={actionLoading === file.id}
                              className="p-1.5 rounded text-slate-400 hover:text-amber-600 hover:bg-amber-50 transition-colors disabled:opacity-50"
                              title="Force expire"
                            >
                              <Clock className="w-3.5 h-3.5" />
                            </button>
                          )}
                          <button
                            onClick={() => handleDelete(file)}
                            disabled={actionLoading === file.id}
                            className="p-1.5 rounded text-slate-400 hover:text-red-600 hover:bg-red-50 transition-colors disabled:opacity-50"
                            title="Delete"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                  {files.length === 0 && (
                    <tr>
                      <td colSpan={6} className="px-4 py-8 text-center text-sm text-slate-500">
                        No files found.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {pagination.pages > 1 && (
            <div className="flex items-center justify-between">
              <p className="text-xs text-slate-500">
                Page {pagination.page} of {pagination.pages}
              </p>
              <div className="flex gap-1">
                <button
                  onClick={() => fetchFiles(pagination.page - 1, search)}
                  disabled={pagination.page <= 1}
                  className="p-2 rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  <ChevronLeft className="w-4 h-4" />
                </button>
                <button
                  onClick={() => fetchFiles(pagination.page + 1, search)}
                  disabled={pagination.page >= pagination.pages}
                  className="p-2 rounded-lg border border-slate-200 text-slate-600 hover:bg-slate-50 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  <ChevronRight className="w-4 h-4" />
                </button>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
