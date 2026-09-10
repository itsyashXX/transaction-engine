.PHONY: help install-backend install-frontend run-backend run-frontend db-up db-down test lint

help:
	@echo "Transaction Engine Baseline Commands"
	@echo "------------------------------------"
	@echo "make install-backend  - Install Python dependencies"
	@echo "make install-frontend - Install Node dependencies"
	@echo "make run-backend      - Start Django server"
	@echo "make run-frontend     - Start React/Vite server"
	@echo "make db-up            - Start MongoDB replica set"
	@echo "make db-down          - Stop MongoDB"
	@echo "make test             - Run backend tests"
	@echo "make lint             - Run linting"

install-backend:
	pip install -r backend/requirements/development.txt

install-frontend:
	cd frontend && npm install

run-backend:
	cd backend && python manage.py runserver 0.0.0.0:8000

run-frontend:
	cd frontend && npm run dev

db-up:
	docker-compose up -d

db-down:
	docker-compose down

test:
	cd backend && pytest

lint:
	cd backend && flake8 .
	cd frontend && npm run lint
