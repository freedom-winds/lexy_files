import { NavLink, Outlet } from 'react-router-dom';
import { Layout } from '../../components/Layout';
import { Users, FileIcon, Layers, BarChart3 } from 'lucide-react';
import clsx from 'clsx';

const navItems = [
  { to: '/admin', label: 'Overview', icon: BarChart3, end: true },
  { to: '/admin/users', label: 'Users', icon: Users, end: false },
  { to: '/admin/files', label: 'Files', icon: FileIcon, end: false },
  { to: '/admin/groups', label: 'Groups', icon: Layers, end: false },
];

export function AdminLayout() {
  return (
    <Layout>
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-8">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-slate-900">Admin Console</h1>
          <p className="text-sm text-slate-500 mt-1">Manage users, files, and system settings</p>
        </div>

        <div className="flex flex-col sm:flex-row gap-6">
          {/* Sidebar nav */}
          <nav className="sm:w-48 shrink-0">
            <div className="flex sm:flex-col gap-1 overflow-x-auto sm:overflow-visible">
              {navItems.map((item) => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  end={item.end}
                  className={({ isActive }) =>
                    clsx(
                      'flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-medium transition-colors whitespace-nowrap',
                      isActive
                        ? 'bg-indigo-50 text-indigo-700'
                        : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
                    )
                  }
                >
                  <item.icon className="w-4 h-4" />
                  {item.label}
                </NavLink>
              ))}
            </div>
          </nav>

          {/* Content */}
          <div className="flex-1 min-w-0">
            <Outlet />
          </div>
        </div>
      </div>
    </Layout>
  );
}
