#!/bin/bash
set -e

echo "Creating UI API client..."
cat << 'API' > frontend/src/api/client.ts
export const apiClient = {
    async login(username, password) {
        const res = await fetch('/api/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username, password })
        });
        if (!res.ok) throw new Error(await res.text());
        return res.json();
    },
    
    async requestTransaction(token, operation, amount_minor, idempotency_key) {
        const res = await fetch('/api/transactions', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify({ operation, amount_minor, idempotency_key })
        });
        if (!res.ok) throw new Error(await res.text());
        return res.json();
    }
}
API

echo "Updating App to include Transaction Lab UI..."
cat << 'APP' > frontend/src/App.tsx
import { useEffect, useState } from 'react';
import { Activity, ShieldCheck, Database, Send, AlertTriangle } from 'lucide-react';
import { apiClient } from './api/client';

function App() {
  const [health, setHealth] = useState('Checking...');
  const [token, setToken] = useState('');
  const [amount, setAmount] = useState('1000');
  const [logs, setLogs] = useState<string[]>([]);
  
  useEffect(() => {
    fetch('/api/health')
      .then(res => res.json())
      .then(data => setHealth(data.data.database === 'CONNECTED' ? 'Online' : 'Offline'))
      .catch(() => setHealth('Error'));
  }, []);

  const handleLogin = async () => {
    try {
      const res = await apiClient.login('demo_user', 'password123');
      setToken(res.data.token);
      setLogs(prev => ['[AUTH] Logged in as demo_user', ...prev]);
    } catch (err: any) {
      setLogs(prev => [`[AUTH ERROR] ${err.message}`, ...prev]);
    }
  };

  const handleTransaction = async (operation: string) => {
    if (!token) return alert('Please login first');
    
    const idempotencyKey = crypto.randomUUID(); // Rule 55: Generate unique key
    setLogs(prev => [`[REQUEST] Sending ${operation} for ₹${Number(amount)/100} (Key: ${idempotencyKey.split('-')[0]}...)`, ...prev]);
    
    try {
      const res = await apiClient.requestTransaction(token, operation, Number(amount), idempotencyKey);
      setLogs(prev => [`[SUCCESS] Status: ${res.status}. ID: ${res.transaction_id}`, ...prev]);
    } catch (err: any) {
      setLogs(prev => [`[ERROR] ${err.message}`, ...prev]);
    }
  };

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
        
        {/* Left Column: Controls */}
        <div className="space-y-6">
            <div className="bg-surface border border-border rounded-lg p-6">
              <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                <ShieldCheck className="w-5 h-5 text-primary" />
                Phase 17: Auth & Security
              </h2>
              {!token ? (
                  <button onClick={handleLogin} className="bg-primary text-background font-bold px-4 py-2 rounded hover:opacity-90">
                    Login Demo User
                  </button>
              ) : (
                  <div className="text-success font-mono text-sm break-all bg-background p-3 rounded border border-border">
                    Token: {token.substring(0, 30)}...
                  </div>
              )}
            </div>

            <div className="bg-surface border border-border rounded-lg p-6">
              <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
                <Send className="w-5 h-5 text-primary" />
                Phase 18: Concurrency Testing
              </h2>
              
              <div className="space-y-4">
                <div>
                    <label className="block text-sm text-slate-400 mb-1">Amount (Minor Units / Paise)</label>
                    <input 
                        type="number" 
                        value={amount}
                        onChange={(e) => setAmount(e.target.value)}
                        className="w-full bg-background border border-border rounded p-2 text-white" 
                    />
                </div>
                
                <div className="flex gap-2">
                    <button 
                        onClick={() => handleTransaction('ADD')}
                        className="flex-1 bg-success text-white font-bold px-4 py-2 rounded hover:opacity-90">
                        ADD
                    </button>
                    <button 
                        onClick={() => handleTransaction('SUBTRACT')}
                        className="flex-1 bg-error text-white font-bold px-4 py-2 rounded hover:opacity-90">
                        SUBTRACT
                    </button>
                </div>
                <p className="text-xs text-slate-400 flex gap-1 mt-2">
                    <AlertTriangle className="w-4 h-4 text-warning" />
                    Generates an automatic Idempotency-Key
                </p>
              </div>
            </div>
        </div>

        {/* Right Column: Logs */}
        <div className="bg-surface border border-border rounded-lg p-6 flex flex-col h-[500px]">
          <h2 className="text-xl font-semibold mb-4 font-mono text-primary">Engine Audit Log</h2>
          <div className="flex-1 bg-background rounded border border-border p-4 overflow-y-auto font-mono text-sm space-y-2">
            {logs.length === 0 ? (
                <span className="text-slate-500">Waiting for events...</span>
            ) : (
                logs.map((log, i) => (
                    <div key={i} className={`${log.includes('ERROR') ? 'text-error' : log.includes('SUCCESS') ? 'text-success' : 'text-slate-300'}`}>
                        {log}
                    </div>
                ))
            )}
          </div>
        </div>
        
      </div>
    </div>
  );
}

export default App;
APP

echo "Done."
