import { Layout } from '../components/Layout';
import { FileUpload } from '../components/FileUpload';
import { PickupCodeInput } from '../components/PickupCodeInput';
import { Upload, Download, Shield, Zap } from 'lucide-react';

export function HomePage() {
  return (
    <Layout>
      {/* Hero */}
      <section className="bg-white border-b border-slate-200">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 py-16 sm:py-20 text-center">
          <div className="inline-flex items-center gap-2 bg-indigo-50 text-indigo-700 text-xs font-medium px-3 py-1.5 rounded-full mb-6 border border-indigo-100">
            <Zap className="w-3 h-3" />
            Fast, simple file sharing
          </div>
          <h1 className="text-4xl sm:text-5xl font-bold text-slate-900 tracking-tight mb-4">
            Share files with a{' '}
            <span className="text-indigo-600">pickup code</span>
          </h1>
          <p className="text-lg text-slate-500 max-w-xl mx-auto">
            Upload any file, get a short code, and share it with anyone. No account required.
          </p>
        </div>
      </section>

      {/* Main actions */}
      <section className="max-w-6xl mx-auto px-4 sm:px-6 py-12">
        <div className="grid sm:grid-cols-2 gap-6">
          {/* Send */}
          <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
            <div className="px-6 py-5 border-b border-slate-100">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-lg bg-indigo-600 flex items-center justify-center">
                  <Upload className="w-4 h-4 text-white" />
                </div>
                <div>
                  <h2 className="text-base font-semibold text-slate-900">Send a File</h2>
                  <p className="text-xs text-slate-500">Upload and get a pickup code</p>
                </div>
              </div>
            </div>
            <div className="p-6">
              <FileUpload />
            </div>
          </div>

          {/* Receive */}
          <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
            <div className="px-6 py-5 border-b border-slate-100">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-lg bg-emerald-600 flex items-center justify-center">
                  <Download className="w-4 h-4 text-white" />
                </div>
                <div>
                  <h2 className="text-base font-semibold text-slate-900">Receive a File</h2>
                  <p className="text-xs text-slate-500">Enter a code to download</p>
                </div>
              </div>
            </div>
            <div className="p-6">
              <PickupCodeInput />
            </div>
          </div>
        </div>
      </section>

      {/* Feature highlights */}
      <section className="max-w-6xl mx-auto px-4 sm:px-6 pb-16">
        <div className="grid sm:grid-cols-3 gap-4">
          <div className="flex items-start gap-3 p-4 rounded-xl bg-white border border-slate-100">
            <div className="w-8 h-8 rounded-lg bg-indigo-50 flex items-center justify-center shrink-0 mt-0.5">
              <Zap className="w-4 h-4 text-indigo-600" />
            </div>
            <div>
              <h3 className="text-sm font-semibold text-slate-800 mb-1">No account needed</h3>
              <p className="text-xs text-slate-500 leading-relaxed">
                Upload files instantly without registering. Create an account for more features.
              </p>
            </div>
          </div>
          <div className="flex items-start gap-3 p-4 rounded-xl bg-white border border-slate-100">
            <div className="w-8 h-8 rounded-lg bg-emerald-50 flex items-center justify-center shrink-0 mt-0.5">
              <Shield className="w-4 h-4 text-emerald-600" />
            </div>
            <div>
              <h3 className="text-sm font-semibold text-slate-800 mb-1">Simple codes</h3>
              <p className="text-xs text-slate-500 leading-relaxed">
                Share a 6-character code instead of long URLs. Easy to type, easy to share.
              </p>
            </div>
          </div>
          <div className="flex items-start gap-3 p-4 rounded-xl bg-white border border-slate-100">
            <div className="w-8 h-8 rounded-lg bg-amber-50 flex items-center justify-center shrink-0 mt-0.5">
              <Download className="w-4 h-4 text-amber-600" />
            </div>
            <div>
              <h3 className="text-sm font-semibold text-slate-800 mb-1">Track your uploads</h3>
              <p className="text-xs text-slate-500 leading-relaxed">
                Registered users can manage uploads, track downloads, and control expiry.
              </p>
            </div>
          </div>
        </div>
      </section>
    </Layout>
  );
}
