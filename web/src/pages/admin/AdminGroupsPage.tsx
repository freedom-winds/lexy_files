import { useEffect, useState } from 'react';
import api from '../../lib/api';
import { formatFileSize, getApiError } from '../../lib/utils';
import { Layers, Save, AlertCircle, CheckCircle } from 'lucide-react';

interface GroupQuota {
  id: number;
  group_name: string;
  download_speed_limit: number;
  max_single_file_size: number;
  max_total_storage: number;
  download_traffic_quota: number;
  traffic_quota_period: string;
  max_retention_seconds: number;
  updated_at: string | null;
}

export function AdminGroupsPage() {
  const [groups, setGroups] = useState<GroupQuota[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [savingGroup, setSavingGroup] = useState<string | null>(null);
  const [editValues, setEditValues] = useState<Record<string, Partial<GroupQuota>>>({});

  useEffect(() => {
    api
      .get<GroupQuota[]>('/admin/groups')
      .then(({ data }) => {
        const groupList = Array.isArray(data) ? data : [];
        setGroups(groupList);
        const initial: Record<string, Partial<GroupQuota>> = {};
        groupList.forEach((g) => {
          initial[g.group_name] = { ...g };
        });
        setEditValues(initial);
      })
      .catch((err) => setError(getApiError(err)))
      .finally(() => setLoading(false));
  }, []);

  const handleFieldChange = (group: string, field: keyof GroupQuota, value: string) => {
    const numVal = parseInt(value, 10);
    if (isNaN(numVal) || numVal < 0) return;
    setEditValues((prev) => ({
      ...prev,
      [group]: { ...prev[group], [field]: numVal },
    }));
  };

  const handlePeriodChange = (group: string, value: string) => {
    setEditValues((prev) => ({
      ...prev,
      [group]: { ...prev[group], traffic_quota_period: value },
    }));
  };

  const handleSave = async (groupName: string) => {
    setSavingGroup(groupName);
    setError(null);
    setSuccess(null);
    try {
      const values = editValues[groupName];
      await api.put(`/admin/groups/${groupName}`, {
        download_speed_limit: values.download_speed_limit,
        max_single_file_size: values.max_single_file_size,
        max_total_storage: values.max_total_storage,
        download_traffic_quota: values.download_traffic_quota,
        traffic_quota_period: values.traffic_quota_period,
        max_retention_seconds: values.max_retention_seconds,
      });
      setSuccess(`"${groupName}" group updated successfully.`);
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      setError(getApiError(err));
    } finally {
      setSavingGroup(null);
    }
  };

  const formatRetention = (seconds: number): string => {
    if (seconds === 0) return 'Unlimited';
    if (seconds < 3600) return `${Math.round(seconds / 60)} min`;
    if (seconds < 86400) return `${Math.round(seconds / 3600)} hours`;
    return `${Math.round(seconds / 86400)} days`;
  };

  const quotaFields: { key: keyof GroupQuota; label: string; hint?: string; formatter?: (v: number) => string }[] = [
    { key: 'download_speed_limit', label: 'Download Speed Limit', hint: 'bytes/s, 0 = unlimited', formatter: (v) => v === 0 ? 'Unlimited' : `${formatFileSize(v)}/s` },
    { key: 'max_single_file_size', label: 'Max Single File Size', hint: 'bytes, 0 = unlimited', formatter: (v) => v === 0 ? 'Unlimited' : formatFileSize(v) },
    { key: 'max_total_storage', label: 'Max Total Storage', hint: 'bytes, 0 = unlimited', formatter: (v) => v === 0 ? 'Unlimited' : formatFileSize(v) },
    { key: 'download_traffic_quota', label: 'Download Traffic Quota', hint: 'bytes per period, 0 = unlimited', formatter: (v) => v === 0 ? 'Unlimited' : formatFileSize(v) },
    { key: 'max_retention_seconds', label: 'Max File Retention', hint: 'seconds, 0 = unlimited', formatter: formatRetention },
  ];

  if (loading) {
    return (
      <div className="flex items-center justify-center py-16">
        <div className="animate-spin rounded-full h-8 w-8 border-2 border-indigo-500 border-t-transparent" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <h2 className="text-lg font-semibold text-slate-900">User Groups</h2>

      {error && (
        <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700 flex items-start gap-2">
          <AlertCircle className="w-4 h-4 mt-0.5 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {success && (
        <div className="p-3 bg-green-50 border border-green-200 rounded-lg text-sm text-green-700 flex items-start gap-2">
          <CheckCircle className="w-4 h-4 mt-0.5 shrink-0" />
          <span>{success}</span>
        </div>
      )}

      {groups.length === 0 && !error && (
        <p className="text-sm text-slate-500 text-center py-8">No groups configured.</p>
      )}

      <div className="space-y-4">
        {groups.map((group) => {
          const vals = editValues[group.group_name] || {};
          return (
            <div
              key={group.group_name}
              className="bg-white rounded-xl border border-slate-200 overflow-hidden"
            >
              <div className="flex items-center gap-3 px-5 py-4 border-b border-slate-100 bg-slate-50">
                <div className="w-8 h-8 rounded-lg bg-indigo-100 flex items-center justify-center">
                  <Layers className="w-4 h-4 text-indigo-600" />
                </div>
                <div>
                  <h3 className="text-sm font-semibold text-slate-800 capitalize">{group.group_name}</h3>
                  <p className="text-xs text-slate-500">Quota defaults for {group.group_name} users</p>
                </div>
              </div>

              <div className="p-5">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {quotaFields.map((field) => {
                    const numVal = (vals[field.key] as number) ?? 0;
                    return (
                      <div key={field.key}>
                        <label htmlFor={`${group.group_name}-${field.key}`} className="block text-xs font-medium text-slate-600 mb-1">
                          {field.label}
                          {field.formatter && (
                            <span className="ml-1 text-slate-400 font-normal">
                              ({field.formatter(numVal)})
                            </span>
                          )}
                        </label>
                        <input
                          id={`${group.group_name}-${field.key}`}
                          type="number"
                          min="0"
                          value={numVal}
                          onChange={(e) => handleFieldChange(group.group_name, field.key, e.target.value)}
                          className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:border-transparent"
                        />
                        {field.hint && (
                          <p className="text-xs text-slate-400 mt-0.5">{field.hint}</p>
                        )}
                      </div>
                    );
                  })}

                  <div>
                    <label htmlFor={`${group.group_name}-traffic_quota_period`} className="block text-xs font-medium text-slate-600 mb-1">
                      Traffic Quota Period
                    </label>
                    <select
                      id={`${group.group_name}-traffic_quota_period`}
                      title="Traffic Quota Period"
                      value={vals.traffic_quota_period as string || 'daily'}
                      onChange={(e) => handlePeriodChange(group.group_name, e.target.value)}
                      className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:border-transparent bg-white"
                    >
                      <option value="daily">Daily</option>
                      <option value="monthly">Monthly</option>
                    </select>
                  </div>
                </div>

                <div className="mt-4 flex justify-end">
                  <button
                    type="button"
                    onClick={() => handleSave(group.group_name)}
                    disabled={savingGroup === group.group_name}
                    className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 disabled:bg-slate-200 disabled:text-slate-400 text-white text-sm font-medium rounded-lg transition-colors"
                  >
                    <Save className="w-4 h-4" />
                    {savingGroup === group.group_name ? 'Saving...' : 'Save Changes'}
                  </button>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
