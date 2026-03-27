import { Routes, Route } from 'react-router-dom';
import { HomePage } from './pages/HomePage';
import { LoginPage } from './pages/LoginPage';
import { RegisterPage } from './pages/RegisterPage';
import { PickupPage } from './pages/PickupPage';
import { MyFilesPage } from './pages/MyFilesPage';
import { DevicesPage } from './pages/DevicesPage';
import { TransferPage } from './pages/TransferPage';
import { AdminLayout } from './pages/admin/AdminLayout';
import { AdminUsersPage } from './pages/admin/AdminUsersPage';
import { AdminFilesPage } from './pages/admin/AdminFilesPage';
import { AdminGroupsPage } from './pages/admin/AdminGroupsPage';
import { AdminStatsPage } from './pages/admin/AdminStatsPage';
import { ProtectedRoute } from './components/ProtectedRoute';
import { AdminRoute } from './components/AdminRoute';

function App() {
  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/register" element={<RegisterPage />} />
      <Route path="/pickup/:code" element={<PickupPage />} />
      <Route
        path="/my-files"
        element={
          <ProtectedRoute>
            <MyFilesPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/devices"
        element={
          <ProtectedRoute>
            <DevicesPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/transfer"
        element={
          <ProtectedRoute>
            <TransferPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/admin"
        element={
          <AdminRoute>
            <AdminLayout />
          </AdminRoute>
        }
      >
        <Route index element={<AdminStatsPage />} />
        <Route path="users" element={<AdminUsersPage />} />
        <Route path="files" element={<AdminFilesPage />} />
        <Route path="groups" element={<AdminGroupsPage />} />
      </Route>
    </Routes>
  );
}

export default App;
