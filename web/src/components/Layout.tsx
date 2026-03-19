import { Link, NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../lib/auth';
import { Files, LogOut, User, LayoutDashboard, Menu, X } from 'lucide-react';
import { useState } from 'react';
import type { ReactNode } from 'react';
import clsx from 'clsx';

interface LayoutProps {
  children: ReactNode;
}

export function Layout({ children }: LayoutProps) {
  const { user, isAuthenticated, logout } = useAuth();
  const navigate = useNavigate();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const handleLogout = async () => {
    await logout();
    navigate('/');
    setMobileMenuOpen(false);
  };

  const navLinkClass = ({ isActive }: { isActive: boolean }) =>
    clsx(
      'text-sm font-medium transition-colors duration-150',
      isActive
        ? 'text-indigo-600'
        : 'text-slate-600 hover:text-slate-900'
    );

  return (
    <div className="min-h-screen flex flex-col bg-slate-50">
      <header className="bg-white border-b border-slate-200 sticky top-0 z-50">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <div className="flex items-center justify-between h-16">
            {/* Logo */}
            <Link to="/" className="flex items-center gap-2 font-semibold text-slate-900 hover:text-indigo-600 transition-colors">
              <div className="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center">
                <Files className="w-4 h-4 text-white" />
              </div>
              <span className="text-lg">Lexy Files</span>
            </Link>

            {/* Desktop nav */}
            <nav className="hidden sm:flex items-center gap-6">
              <NavLink to="/" end className={navLinkClass}>
                Home
              </NavLink>
              {isAuthenticated && (
                <NavLink to="/my-files" className={navLinkClass}>
                  My Files
                </NavLink>
              )}
              {user?.user_group === 'admin' && (
                <NavLink to="/admin" className={navLinkClass}>
                  Admin
                </NavLink>
              )}
            </nav>

            {/* Desktop auth */}
            <div className="hidden sm:flex items-center gap-3">
              {isAuthenticated ? (
                <>
                  <div className="flex items-center gap-2 text-sm text-slate-600">
                    <div className="w-7 h-7 rounded-full bg-indigo-100 flex items-center justify-center">
                      <User className="w-3.5 h-3.5 text-indigo-600" />
                    </div>
                    <span className="font-medium">{user?.username}</span>
                  </div>
                  <button
                    onClick={handleLogout}
                    className="flex items-center gap-1.5 text-sm text-slate-600 hover:text-slate-900 transition-colors"
                  >
                    <LogOut className="w-4 h-4" />
                    Sign out
                  </button>
                </>
              ) : (
                <>
                  <Link
                    to="/login"
                    className="text-sm font-medium text-slate-600 hover:text-slate-900 transition-colors"
                  >
                    Sign in
                  </Link>
                  <Link
                    to="/register"
                    className="text-sm font-medium bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-1.5 rounded-lg transition-colors"
                  >
                    Register
                  </Link>
                </>
              )}
            </div>

            {/* Mobile menu button */}
            <button
              className="sm:hidden p-2 rounded-md text-slate-600 hover:text-slate-900 hover:bg-slate-100 transition-colors"
              onClick={() => setMobileMenuOpen((v) => !v)}
              aria-label="Toggle menu"
            >
              {mobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
            </button>
          </div>
        </div>

        {/* Mobile menu */}
        {mobileMenuOpen && (
          <div className="sm:hidden border-t border-slate-200 bg-white px-4 py-3 space-y-1">
            <NavLink
              to="/"
              end
              className={({ isActive }) =>
                clsx('block px-3 py-2 rounded-md text-sm font-medium transition-colors', isActive ? 'bg-indigo-50 text-indigo-600' : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900')
              }
              onClick={() => setMobileMenuOpen(false)}
            >
              Home
            </NavLink>
            {isAuthenticated && (
              <NavLink
                to="/my-files"
                className={({ isActive }) =>
                  clsx('block px-3 py-2 rounded-md text-sm font-medium transition-colors', isActive ? 'bg-indigo-50 text-indigo-600' : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900')
                }
                onClick={() => setMobileMenuOpen(false)}
              >
                My Files
              </NavLink>
            )}
            {user?.user_group === 'admin' && (
              <NavLink
                to="/admin"
                className={({ isActive }) =>
                  clsx('block px-3 py-2 rounded-md text-sm font-medium transition-colors', isActive ? 'bg-indigo-50 text-indigo-600' : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900')
                }
                onClick={() => setMobileMenuOpen(false)}
              >
                Admin
              </NavLink>
            )}
            <div className="pt-2 border-t border-slate-100">
              {isAuthenticated ? (
                <>
                  <div className="px-3 py-2 text-sm text-slate-600">
                    Signed in as <span className="font-medium">{user?.username}</span>
                  </div>
                  <button
                    onClick={handleLogout}
                    className="w-full text-left px-3 py-2 rounded-md text-sm font-medium text-slate-600 hover:bg-slate-50 hover:text-slate-900 transition-colors"
                  >
                    Sign out
                  </button>
                </>
              ) : (
                <>
                  <Link
                    to="/login"
                    className="block px-3 py-2 rounded-md text-sm font-medium text-slate-600 hover:bg-slate-50 hover:text-slate-900 transition-colors"
                    onClick={() => setMobileMenuOpen(false)}
                  >
                    Sign in
                  </Link>
                  <Link
                    to="/register"
                    className="block px-3 py-2 rounded-md text-sm font-medium text-indigo-600 hover:bg-indigo-50 transition-colors"
                    onClick={() => setMobileMenuOpen(false)}
                  >
                    Register
                  </Link>
                </>
              )}
            </div>
          </div>
        )}
      </header>

      <main className="flex-1">
        {children}
      </main>

      <footer className="bg-white border-t border-slate-200 mt-auto">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 py-6">
          <div className="flex flex-col sm:flex-row items-center justify-between gap-3 text-sm text-slate-500">
            <div className="flex items-center gap-2">
              <div className="w-5 h-5 bg-indigo-600 rounded flex items-center justify-center">
                <Files className="w-3 h-3 text-white" />
              </div>
              <span>Lexy Files</span>
            </div>
            <div className="flex items-center gap-4">
              <Link to="/" className="hover:text-slate-900 transition-colors">Home</Link>
              {isAuthenticated ? (
                <Link to="/my-files" className="hover:text-slate-900 transition-colors">My Files</Link>
              ) : (
                <>
                  <Link to="/login" className="hover:text-slate-900 transition-colors">Sign in</Link>
                  <Link to="/register" className="hover:text-slate-900 transition-colors">Register</Link>
                </>
              )}
              {user?.user_group === 'admin' && (
                <Link to="/admin" className="hover:text-slate-900 transition-colors flex items-center gap-1">
                  <LayoutDashboard className="w-3 h-3" />
                  Admin
                </Link>
              )}
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
