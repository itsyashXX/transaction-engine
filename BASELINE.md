# BASELINE RECORD

As dictated by **PHASE 2 (BASELINE)** of the Master Engineering Hive Prompt, this document records the *actual* commands established for the Transaction Engine project.

Because this is a greenfield implementation, these commands are established strictly via the newly created `Makefile` and structural scaffolding, ensuring no commands are "invented" during subsequent phases.

## Validated Commands

- **Backend Startup**: `make run-backend` (Executes: `cd backend && python manage.py runserver 0.0.0.0:8000`)
- **Frontend Startup**: `make run-frontend` (Executes: `cd frontend && npm run dev`)
- **Database Startup**: `make db-up` (Executes: `docker-compose up -d` starting a MongoDB replica set for transaction support)
- **Tests**: `make test` (Executes: `cd backend && pytest`)
- **Lint**: `make lint` (Executes: `flake8` and `npm run lint`)

## Package Configurations

- **Environment**: Configured via `.env.example` containing essential settings (`MONGODB_URI`, timeouts, JWT configuration, queue poll intervals).
- **Docker**: Configured via `docker-compose.yml` to spin up MongoDB 6.0 with replica set (`rs0`) enabled. *Replica sets are mandatory for MongoDB multi-document transactions*.
