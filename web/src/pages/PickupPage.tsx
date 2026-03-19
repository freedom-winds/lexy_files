import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { Layout } from '../components/Layout';
import api from '../lib/api';
import { formatFileSize, formatRelativeDate, getApiError } from '../lib/utils';
import { Download, FileIcon, Clock, AlertCircle, ArrowLeft } from 'lucide-react';

interface FileInfo {
  id: number;
  original_filename: string;
  file_size: number;
  mime_type: string;
  expires_at: string;
  download_count: number;
  max_downloads: number | null;
}

export function PickupPage() {
  const { code } = useParams<{ code: string }>();
  const [file, setFile] = useState<FileInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [downloading, setDownloading] = useState(false);

  useEffect(() => {
    if (!code) return;
    setLoading(true);
    setError(null);
    api
      .get<FileInfo>(`/files/pickup/${code}`)
      .then(({ data }) => setFile(data))
      .catch((err) => setError(getApiError(err)))
      .finally(() => setLoading(false));
  }, [code]);

  const handleDownload = async () => {
    if (!file) return;
    setDownloading(true);
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
      // refresh file info to update download count
      const { data } = await api.get<FileInfo>(`/files/pickup/${code}`);
      setFile(data);
    } catch (err) {
      setError(getApiError(err));
    } finally {
      setDownloading(false);
    }
  };

  return (
    <Layout>
      <div className="max-w-lg mx-auto px-4 sm:px-6 py-12">
        <Link
          to="/"
          className="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-slate-700 transition-colors mb-6"
        >
          <ArrowLeft className="w-4 h-4" />
          Back to home
        </Link>

        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
          <div className="px-6 py-5 border-b border-slate-100">
            <h1 className="text-lg font-semibold text-slate-900">
              Pickup Code: <span className="font-mono tracking-widest text-indigo-600">{code}</span>
            </h1>
          </div>

          <div className="p-6">
            {loading && (
              <div className="flex items-center justify-center py-12">
                <div className="animate-spin rounded-full h-8 w-8 border-2 border-indigo-500 border-t-transparent" />
              </div>
            )}

            {error && !loading && (
              <div className="flex flex-col items-center gap-4 py-8 text-center">
                <div className="w-12 h-12 rounded-full bg-red-50 flex items-center justify-center">
                  <AlertCircle className="w-6 h-6 text-red-500" />
                </div>
                <div>
                  <p className="text-sm font-medium text-slate-800 mb-1">File not found</p>
                  <p className="text-sm text-slate-500">{error}</p>
                </div>
                <Link
                  to="/"
                  className="text-sm text-indigo-600 font-medium hover:text-indigo-700 transition-colors"
                >
                  Try another code
                </Link>
              </div>
            )}

            {file && !loading && (
              <div className="space-y-5">
                <div className="flex items-start gap-4 p-4 bg-slate-50 rounded-xl border border-slate-100">
                  <div className="w-10 h-10 rounded-lg bg-indigo-100 flex items-center justify-center shrink-0">
                    <FileIcon className="w-5 h-5 text-indigo-600" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium text-slate-800 truncate">
                      {file.original_filename}
                    </p>
                    <p className="text-xs text-slate-500 mt-0.5">
                      {formatFileSize(file.file_size)} &middot; {file.mime_type}
                    </p>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div className="p-3 bg-slate-50 rounded-lg border border-slate-100">
                    <div className="flex items-center gap-1.5 text-xs text-slate-500 mb-1">
                      <Clock className="w-3 h-3" />
                      Expires
                    </div>
                    <p className="text-sm font-medium text-slate-800">
                      {formatRelativeDate(file.expires_at)}
                    </p>
                  </div>
                  <div className="p-3 bg-slate-50 rounded-lg border border-slate-100">
                    <div className="flex items-center gap-1.5 text-xs text-slate-500 mb-1">
                      <Download className="w-3 h-3" />
                      Downloads
                    </div>
                    <p className="text-sm font-medium text-slate-800">
                      {file.download_count}
                      {file.max_downloads != null && ` / ${file.max_downloads}`}
                    </p>
                  </div>
                </div>

                <button
                  onClick={handleDownload}
                  disabled={downloading}
                  className="w-full flex items-center justify-center gap-2 py-3 bg-indigo-600 hover:bg-indigo-700 disabled:bg-slate-200 disabled:text-slate-400 text-white text-sm font-medium rounded-xl transition-colors"
                >
                  <Download className="w-4 h-4" />
                  {downloading ? 'Downloading...' : 'Download File'}
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </Layout>
  );
}
