# Makefile de PatrickOS / Watson.
# Mantén los targets simples y declarativos: cada uno hace una cosa.

PYTHON ?= python3

.PHONY: watson install test lint iso clean help check pr merge fix-perms check-installed

help:
	@echo "Targets disponibles:"
	@echo "  make watson    - Ejecuta Watson desde el repo (sin instalar)."
	@echo "  make install   - Instala Watson en /usr/local/ (requiere sudo)."
	@echo "  make test      - Ejecuta pytest si está disponible."
	@echo "  make lint      - shellcheck en scripts + compilación de watson.py."
	@echo "  make check     - Pasada rápida pre-PR (lint + smoke de Watson)."
	@echo "  make check-installed - Verifica que /usr/local/bin/watson está en sync con el repo."
	@echo "  make pr        - Abre PR contra main. Uso: make pr TITLE=\"...\""
	@echo "  make merge     - Mergea PR actual (squash) y vuelve a main. PR=N opcional."
	@echo "  make fix-perms - chmod +x scripts/*.sh (rescate post-edición Windows/WSL)."
	@echo "  make iso       - (Día 4) Construye la ISO con live-build."
	@echo "  make clean     - Borra cachés de Python y pytest."

watson:
	$(PYTHON) watson/watson.py

install:
	sudo bash scripts/install.sh

# pytest debe no fallar si todavía no hay tests.
test:
	@if command -v pytest >/dev/null 2>&1; then \
		pytest --no-header -q || true; \
	else \
		echo "pytest no instalado; saltando tests."; \
	fi

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck scripts/*.sh; \
	else \
		echo "shellcheck no instalado; saltando lint de bash."; \
	fi
	$(PYTHON) -m py_compile watson/watson.py

check:
	bash scripts/dev-check.sh

check-installed:
	bash scripts/check-installed-watson.sh

fix-perms:
	bash scripts/fix-script-perms.sh

# Uso: make pr TITLE="feat: algo"
pr:
	@if [ -z "$(TITLE)" ]; then \
		echo "Uso: make pr TITLE=\"feat: algo\""; \
		exit 1; \
	fi
	bash scripts/pr-create.sh main "$(TITLE)"

# Uso: make merge          (PR de la rama actual)
#      make merge PR=42    (PR específico)
merge:
	bash scripts/pr-merge.sh $(PR)

iso:
	@echo "Día 4: pendiente. Aquí construiremos la ISO con live-build."

clean:
	rm -rf __pycache__ watson/__pycache__ .pytest_cache
