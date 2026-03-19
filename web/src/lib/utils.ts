export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  const value = bytes / Math.pow(1024, i);
  return `${value % 1 === 0 ? value : value.toFixed(1)} ${units[i]}`;
}

export function formatDate(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function formatRelativeDate(iso: string): string {
  const d = new Date(iso);
  const now = new Date();
  const diffMs = d.getTime() - now.getTime();
  const diffSecs = Math.round(diffMs / 1000);
  const diffMins = Math.round(diffSecs / 60);
  const diffHours = Math.round(diffMins / 60);
  const diffDays = Math.round(diffHours / 24);

  if (diffMs < 0) return 'Expired';
  if (diffDays > 1) return `in ${diffDays} days`;
  if (diffDays === 1) return 'in 1 day';
  if (diffHours > 1) return `in ${diffHours} hours`;
  if (diffHours === 1) return 'in 1 hour';
  if (diffMins > 1) return `in ${diffMins} minutes`;
  return 'in less than a minute';
}

export function getApiError(err: unknown): string {
  if (err && typeof err === 'object') {
    const e = err as {
      response?: {
        data?: {
          error?: { code?: string; message?: string } | string;
          message?: string;
        };
      };
      message?: string;
    };
    const errData = e.response?.data?.error;
    if (errData && typeof errData === 'object' && errData.message) return errData.message;
    if (typeof errData === 'string') return errData;
    if (e.response?.data?.message) return e.response.data.message;
    if (e.message) return e.message;
  }
  return 'An unexpected error occurred.';
}
