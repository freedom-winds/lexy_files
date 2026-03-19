import { useEffect, useState } from 'react';
import api from '../../lib/api';
import { formatFileSize, getApiError } from '../../lib/utils';
import { Users, FileIcon, HardDrive, Activity, AlertCircle } from 'lucide-react';

interface SystemStats {
  total_users: number;
  active_users: number;
  anonymous_users: number;
  total_files: number;
  active_files: number;
  expired_files: number;
  total_storage_bytes: number;
  total_downloads: number;
  total_transfers: number;
}

export function AdminStatsPage() {
  const [stats, setStats] = useState<SystemStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api
      .get<SystemStats>('/admin/stats')
      .then(({ data }) => setStats(data))
      .catch((err) => setError(getApiError(err)))
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-16">
        <div className="animate-spin rounded-full h-8 w-8 border-2 border-indigo-500 border-t-transparent" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700 flex items-start gap-2">
        <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
        <span>{error}</span>
      </div>
    );
  }

  if (!stats) return null;

  const cards = [
    {
      title: 'Total Users',
      value: stats.total_users,
      subtitle: `${stats.active_users} active, ${stats.anonymous_users} anonymous`,
      icon: Users,
      color: 'indigo',
    },
    {
      title: 'Total Files',
      value: stats.total_files,
      subtitle: `${stats.active_files} active, ${stats.expired_files} expired`,
      icon: FileIcon,
      color: 'emerald',
    },
    {
      title: 'Storage Used',
      value: formatFileSize(stats.total_storage_bytes),
      subtitle: `${stats.total_downloads} total downloads`,
      icon: HardDrive,
      color: 'amber',
    },
    {
      title: 'Transfers',
      value: stats.total_transfers,
      subtitle: 'Total transfer sessions',
      icon: Activity,
      color: 'violet',
    },
  ];

  const colorMap: Record<string, { bg: string; iconBg: string; iconColor: string }> = {
    indigo: { bg: 'bg-indigo-50', iconBg: 'bg-indigo-100', iconColor: 'text-indigo-600' },
    emerald: { bg: 'bg-emerald-50', iconBg: 'bg-emerald-100', iconColor: 'text-emerald-600' },
    amber: { bg: 'bg-amber-50', iconBg: 'bg-amber-100', iconColor: 'text-amber-600' },
    violet: { bg: 'bg-violet-50', iconBg: 'bg-violet-100', iconColor: 'text-violet-600' },
  };

  return (
    <div className="space-y-6">
      <h2 className="text-lg font-semibold text-slate-900">System Overview</h2>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        {cards.map((card) => {
          const colors = colorMap[card.color];
          return (
            <div
              key={card.title}
              className={`${colors.bg} rounded-xl border border-slate-100 p-5`}
            >
              <div className="flex items-start gap-3">
                <div className={`w-10 h-10 rounded-lg ${colors.iconBg} flex items-center justify-center`}>
                  <card.icon className={`w-5 h-5 ${colors.iconColor}`} />
                </div>
                <div>
                  <p className="text-xs font-medium text-slate-500 uppercase tracking-wide">
                    {card.title}
                  </p>
                  <p className="text-2xl font-bold text-slate-900 mt-1">{card.value}</p>
                  <p className="text-xs text-slate-500 mt-0.5">{card.subtitle}</p>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
