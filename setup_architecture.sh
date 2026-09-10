#!/bin/bash
set -e

echo "Creating backend directories..."
mkdir -p backend/config/settings backend/apps/users backend/apps/transactions backend/apps/queue backend/apps/workers
mkdir -p backend/db/repositories backend/db/migrations backend/domain backend/services backend/workers backend/intelligence backend/common backend/tests
mkdir -p backend/requirements

echo "Writing backend requirements..."
cat << 'REQ' > backend/requirements/base.txt
Django>=4.2
djangorestframework>=3.14
pymongo>=4.6
python-dotenv>=1.0
PyJWT>=2.8
pytest>=7.4
REQ
cp backend/requirements/base.txt backend/requirements/development.txt

echo "Writing MongoDB authoritative connection (Phase 3 & 4)..."
cat << 'DB' > backend/db/connection.py
import os
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure

class DatabaseConfig:
    URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
    DB_NAME = os.getenv("MONGODB_DATABASE", "transaction_engine")
    TIMEOUT = int(os.getenv("MONGODB_SERVER_SELECTION_TIMEOUT_MS", 5000))

class MongoManager:
    _client = None

    @classmethod
    def get_client(cls):
        if cls._client is None:
            # ONE authoritative MongoClient lifecycle
            cls._client = MongoClient(
                DatabaseConfig.URI,
                serverSelectionTimeoutMS=DatabaseConfig.TIMEOUT,
                connectTimeoutMS=int(os.getenv("MONGODB_CONNECT_TIMEOUT_MS", 10000)),
                socketTimeoutMS=int(os.getenv("MONGODB_SOCKET_TIMEOUT_MS", 10000)),
            )
        return cls._client

    @classmethod
    def get_db(cls):
        return cls.get_client()[DatabaseConfig.DB_NAME]

    @classmethod
    def check_health(cls):
        try:
            cls.get_client().admin.command('ping')
            return True
        except ConnectionFailure:
            return False
DB

echo "Writing backend structure (Django Base)..."
cat << 'MNG' > backend/manage.py
#!/usr/bin/env python
import os
import sys

def main():
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.base')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError("Couldn't import Django.") from exc
    execute_from_command_line(sys.argv)

if __name__ == '__main__':
    main()
MNG

cat << 'STG' > backend/config/settings/base.py
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()
BASE_DIR = Path(__file__).resolve().parent.parent.parent
SECRET_KEY = os.getenv('JWT_SECRET', 'fallback-secret-key-do-not-use-in-prod')
DEBUG = os.getenv('DEBUG', 'True') == 'True'
ALLOWED_HOSTS = ['*']

INSTALLED_APPS = [
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'rest_framework',
]
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.middleware.common.CommonMiddleware',
]
ROOT_URLCONF = 'config.urls'
WSGI_APPLICATION = 'config.wsgi.application'
DATABASES = {} # Using PyMongo directly, Django ORM bypassed for core domain
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_TZ = True
STG

cat << 'URLS' > backend/config/urls.py
from django.urls import path
from django.http import JsonResponse
from db.connection import MongoManager

def health_check(request):
    db_ok = MongoManager.check_health()
    return JsonResponse({
        "success": True,
        "data": {
            "status": "UP" if db_ok else "DOWN",
            "database": "CONNECTED" if db_ok else "DISCONNECTED"
        }
    }, status=200 if db_ok else 503)

urlpatterns = [
    path('api/health', health_check),
]
URLS

cat << 'WSGI' > backend/config/wsgi.py
import os
from django.core.wsgi import get_wsgi_application
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.base')
application = get_wsgi_application()
WSGI

echo "Creating frontend directories..."
mkdir -p frontend/src/api frontend/src/components/ui frontend/src/features/transactions frontend/src/hooks frontend/src/pages frontend/src/types

echo "Writing frontend base files..."
cat << 'PKG' > frontend/package.json
{
  "name": "transaction-engine-frontend",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "lint": "eslint . --ext ts,tsx --report-unused-disable-directives --max-warnings 0",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.22.0",
    "lucide-react": "^0.344.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.56",
    "@types/react-dom": "^18.2.19",
    "@vitejs/plugin-react": "^4.2.1",
    "autoprefixer": "^10.4.17",
    "postcss": "^8.4.35",
    "tailwindcss": "^3.4.1",
    "typescript": "^5.2.2",
    "vite": "^5.1.4"
  }
}
PKG

cat << 'VITE' > frontend/vite.config.ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    proxy: {
      '/api': 'http://localhost:8000'
    }
  }
})
VITE

cat << 'TSCFG' > frontend/tsconfig.json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
TSCFG

cat << 'TSCFG_NODE' > frontend/tsconfig.node.json
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true,
    "strict": true
  },
  "include": ["vite.config.ts"]
}
TSCFG_NODE

cat << 'TAILWIND' > frontend/tailwind.config.js
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        background: '#0f172a',
        surface: '#1e293b',
        border: '#334155',
        primary: '#38bdf8',
        success: '#059669',
        error: '#dc2626',
        warning: '#d97706'
      }
    },
  },
  plugins: [],
}
TAILWIND

cat << 'POSTCSS' > frontend/postcss.config.js
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
POSTCSS

cat << 'INDX' > frontend/index.html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Transaction Engine Lab</title>
  </head>
  <body class="bg-background text-slate-100 min-h-screen">
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
INDX

cat << 'MAIN' > frontend/src/main.tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
MAIN

cat << 'CSS' > frontend/src/index.css
@tailwind base;
@tailwind components;
@tailwind utilities;
CSS

cat << 'APP' > frontend/src/App.tsx
import React, { useEffect, useState } from 'react';
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
APP

echo "Files generated successfully!"
