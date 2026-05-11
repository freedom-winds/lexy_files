import { createContext, useContext } from 'react';

export interface User {
  id: number;
  username: string | null;
  email: string | null;
  user_group: string;
  is_anonymous: boolean;
  is_banned: boolean;
  created_at: string;
}

export interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (username: string, password: string) => Promise<void>;
  register: (username: string, email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshUser: () => Promise<void>;
  ensureAnonymousSession: () => Promise<void>;
}

export const AuthContext = createContext<AuthState>(null!);
export const useAuth = () => useContext(AuthContext);
