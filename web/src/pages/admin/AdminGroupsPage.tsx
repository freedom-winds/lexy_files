import { useEffect, useState } from 'react';
import api from '../../lib/api';
import { formatFileSize, getApiError } from '../../lib/utils';
import { Layers, Save, AlertCircle, CheckCircle } from 'lucide-react';

interface GroupQuota {
  name: string;
  max_file_size: number;
  max_storage: number;
  max_daily_uploads: number;
  max_daily_downloads: number;
  max_daily_traffic: number;
  max_upload_speed: number;
  max_download_speed: number;
  file_expiry_hours: number;
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
          initial[g.name] = { ...g };
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

  const handleSave = async (groupName: string) => {
    setSavingGroup(groupName);
    setError(null);
    setSuccess(null);
    try {
      const values = editValues[groupName];
      await api.put(`/admin/groups/${groupName}`, values);
      setSuccess(`"${groupName}" group updated successfully.`);
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      setError(getApiError(err));
    } finally {
      setSavingGroup(null);
    }
  };

  const quotaFields: { key: keyof GroupQuota; label: string; formatter?: (v: number) => string }[] = [
    { key: 'max_file_size', label: 'Max File Size', formatter: formatFileSize },
    { key: 'max_storage', label: 'Max Storage', formatter: formatFileSize },
    { key: 'max_daily_uploads', label: 'Daily Upload Limit' },
    { key: 'max_daily_downloads', label: 'Daily Download Limit' },
    { key: 'max_daily_traffic', label: 'Daily Traffic', formatter: formatFileSize },
    { key: 'max_upload_speed', label: 'Upload Speed (B/s)', formatter: (v) => `${formatFileSize(v)}/s` },
    { key: 'max_download_speed', label: 'Download Speed (B/s)', formatter: (v) => `${formatFileSize(v)}/s` },
    { key: 'file_expiry_hours', label: 'File Expiry (hours)' },
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
        {groups.map((group) => (
          <div
            key={group.name}
            className="bg-white rounded-xl border border-slate-200 overflow-hidden"
          >
            <div className="flex items-center gap-3 px-5 py-4 border-b border-slate-100 bg-slate-50">
              <div className="w-8 h-8 rounded-lg bg-indigo-100 flex items-center justify-center">
                <Layers className="w-4 h-4 text-indigo-600" />
              </div>
              <div>
                <h3 className="text-sm font-semibold text-slate-800 capitalize">{group.name}</h3>
                <p className="text-xs text-slate-500">Quota defaults for {group.name} users</p>
              </div>
            </div>

            <div className="p-5">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {quotaFields.map((field) => (
                  <div key={field.key}>
                    <label className="block text-xs font-medium text-slate-600 mb-1">
                      {field.label}
                      {field.formatter && (
                        <span className="ml-1 text-slate-400 font-normal">
                          ({field.formatter((editValues[group.name]?.[field.key] as number) || 0)})
                        </span>
                      )}
                    </label>
                    <input
                      type="number"
                      min="0"
                      value={(editValues[group.name]?.[field.key] as number) || 0}
                      onChange={(e) => handleFieldChange(group.name, field.key, e.target.value)}
                      className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-indigo-400 focus:border-transparent"
                    />
                  </div>
                ))}
              </div>

              <div className="mt-4 flex justify-end">
                <button
                  onClick={() => handleSave(group.name)}
                  disabled={savingGroup === group.name}
                  className="flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 disabled:bg-slate-200 disabled:text-slate-400 text-white text-sm font-medium rounded-lg transition-colors"
                >
                  <Save className="w-4 h-4" />
                  {savingGroup === group.name ? 'Saving...' : 'Save Changes'}
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
