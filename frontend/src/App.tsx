import { useEffect, useState } from 'react';
import { Activity, ShieldCheck, Database } from 'lucide-react';

function App() {
  const [health, setHealth] = useState<string>('Checking...');

  useEffect(() => {
    fetch('/api/health')
      .then(res => res.json())
      .then(data => setHealth(data.data.database === 'CONNECTED' ? 'Online' : 'Offline'))
      .catch(() => setHealth('Error'));
  }, []);

  return (
    <div className="p-8 max-w-4xl mx-auto">
      <header className="mb-12 border-b border-border pb-6 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-primary flex items-center gap-3">
            <Database className="w-8 h-8" />
            Transaction Engine
          </h1>
          <p className="text-slate-400 mt-2">Production-Grade DBMS Laboratory</p>
        </div>
        <div className="flex items-center gap-2 bg-surface px-4 py-2 rounded-full border border-border">
          <Activity className={`w-4 h-4 ${health === 'Online' ? 'text-success' : 'text-error'}`} />
          <span className="text-sm font-medium">DB Status: {health}</span>
        </div>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-surface border border-border rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
            <ShieldCheck className="w-5 h-5 text-primary" />
            Phase 4: Architecture
          </h2>
          <ul className="space-y-3 text-slate-300">
            <li className="flex items-start gap-2">
              <span className="text-success mt-1">✓</span>
              <span>Centralized MongoDB Connection Lifecycle</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-success mt-1">✓</span>
              <span>Django Backend Scaffolded</span>
            </li>
            <li className="flex items-start gap-2">
              <span className="text-success mt-1">✓</span>
              <span>React + Vite Frontend Scaffolded</span>
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}

export default App;
