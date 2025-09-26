.PHONY:  install help pull-cr sync-cr

help:
	@echo "Available commands:"
	@echo "  install                Install dependencies and update cursor rules"
	@echo "  pull-cr    Update the .cursorrules file from the remote repository"
	@echo "  help                   Show this help message"


install:
	$(MAKE) pull-cr

pull-cr:
	git clone --depth 1 git@github.com:NolanAguirre/cursor-rules.git /tmp/cursor-rules && cp /tmp/cursor-rules/.cursorrules .cursorrules && rm -rf /tmp/cursor-rules

sync-cr:
	./sync-cr
