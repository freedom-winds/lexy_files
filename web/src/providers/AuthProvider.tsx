import { useState, useEffect, useCallback } from 'react';
import type { ReactNode } from 'react';
import { AuthContext } from '../lib/auth';
import type { User } from '../lib/auth';
import api from '../lib/api';

interface AuthProviderProps {
  children: ReactNode;
}

const ANON_DEVICE_ID_KEY = 'lexy_anon_device_id';
const ANON_FINGERPRINT_KEY = 'lexy_anon_fingerprint';

function getOrCreateClientId(key: string) {
  let value = localStorage.getItem(key);
  if (!value) {
    value = crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
    localStorage.setItem(key, value);
  }
  return value;
}

export function AuthProvider({ children }: AuthProviderProps) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const refreshUser = useCallback(async () => {
    const token = localStorage.getItem('access_token');
    if (!token) {
      setUser(null);
      setIsLoading(false);
      return;
    }
    try {
      const { data } = await api.get<{ user: User }>('/auth/me');
      setUser(data.user);
    } catch {
      setUser(null);
      localStorage.removeItem('access_token');
      localStorage.removeItem('refresh_token');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    refreshUser();
  }, [refreshUser]);

  const login = useCallback(async (username: string, password: string) => {
    const { data } = await api.post<{
      tokens: { access_token: string; refresh_token: string };
      user: User;
    }>('/auth/login', { username, password });
    localStorage.setItem('access_token', data.tokens.access_token);
    localStorage.setItem('refresh_token', data.tokens.refresh_token);
    setUser(data.user);
  }, []);

  const register = useCallback(async (username: string, email: string, password: string) => {
    const { data } = await api.post<{
      tokens: { access_token: string; refresh_token: string };
      user: User;
    }>('/auth/register', { username, email, password });
    localStorage.setItem('access_token', data.tokens.access_token);
    localStorage.setItem('refresh_token', data.tokens.refresh_token);
    setUser(data.user);
  }, []);

  const ensureAnonymousSession = useCallback(async () => {
    if (localStorage.getItem('access_token')) return;
    const { data } = await api.post<{
      tokens: { access_token: string; refresh_token: string };
      user: User;
    }>('/auth/anonymous', {
      device_id: getOrCreateClientId(ANON_DEVICE_ID_KEY),
      fingerprint: getOrCreateClientId(ANON_FINGERPRINT_KEY),
    });
    localStorage.setItem('access_token', data.tokens.access_token);
    localStorage.setItem('refresh_token', data.tokens.refresh_token);
    setUser(data.user);
  }, []);

  const logout = useCallback(async () => {
    try {
      await api.post('/auth/logout');
    } catch {
      // Ignore logout errors — clear state regardless
    } finally {
      localStorage.removeItem('access_token');
      localStorage.removeItem('refresh_token');
      setUser(null);
    }
  }, []);

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated: !!user && !user.is_anonymous,
        isLoading,
        login,
        register,
        logout,
        refreshUser,
        ensureAnonymousSession,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}
