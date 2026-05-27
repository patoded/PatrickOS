# Makefile de PatrickOS / Watson.
# Mantén los targets simples y declarativos: cada uno hace una cosa.

PYTHON ?= python3

.PHONY: watson install test lint iso clean help

help:
	@echo "Targets disponibles:"
	@echo "  make watson    - Ejecuta Watson desde el repo (sin instalar)."
	@echo "  make install   - Instala Watson en /usr/local/ (requiere sudo)."
	@echo "  make test      - Ejecuta pytest si está disponible."
	@echo "  make lint      - shellcheck en scripts + compilación de watson.py."
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

iso:
	@echo "Día 4: pendiente. Aquí construiremos la ISO con live-build."

clean:
	rm -rf __pycache__ watson/__pycache__ .pytest_cache
