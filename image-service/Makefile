.PHONY: start help

start:
	envdir ./env-dev python3 -m uvicorn --app-dir ./src server:app 

test:
	./tests/server

help:
	@echo "Available targets:"
	@echo "  start   Start the FastAPI server in ./src/server.py"
	@echo "  help    Show this help message"
