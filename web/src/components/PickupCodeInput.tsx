import { useState, FormEvent, ChangeEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search } from 'lucide-react';
import clsx from 'clsx';

export function PickupCodeInput() {
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();

  const handleChange = (e: ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 6);
    setCode(val);
    setError(null);
  };

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    if (code.length < 6) {
      setError('Pickup codes are 6 characters long.');
      return;
    }
    navigate(`/pickup/${code}`);
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-3">
      <div className="flex gap-2">
        <input
          type="text"
          value={code}
          onChange={handleChange}
          placeholder="Enter 6-character code"
          maxLength={6}
          spellCheck={false}
          autoComplete="off"
          aria-label="Pickup code"
          className={clsx(
            'flex-1 border rounded-lg px-4 py-2.5 text-sm font-mono tracking-widest uppercase text-slate-800 placeholder:normal-case placeholder:tracking-normal placeholder:font-sans placeholder:text-slate-400 bg-white focus:outline-none focus:ring-2 focus:ring-indigo-400 transition-colors',
            error ? 'border-red-300' : 'border-slate-200'
          )}
        />
        <button
          type="submit"
          className="flex items-center gap-2 px-4 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium rounded-lg transition-colors"
        >
          <Search className="w-4 h-4" />
          Find
        </button>
      </div>
      {error && (
        <p className="text-xs text-red-600">{error}</p>
      )}
      <p className="text-xs text-slate-400">
        Enter the 6-character code shared by the sender to retrieve files.
      </p>
    </form>
  );
}
