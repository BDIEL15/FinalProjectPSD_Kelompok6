# Game Jump-to-Flap (C).
#   make pc        build alat uji untuk PC (Windows: mingw32-make pc)
#   make check     SEMUA uji: selftest Python, jejak Python vs C, register -> gambar
#   make trace     hanya uji jejak Python vs C
#   make clean
# Nanti untuk board: make board CC=arm-linux-gnueabihf-gcc (setelah main.c ada).

CC      = gcc
CFLAGS  ?= -std=c99 -O2 -Wall -Wextra -Wpedantic
LDLIBS  = -lm
PYTHON  ?= python

ifeq ($(OS),Windows_NT)
EXE = .exe
endif

GAME_SRC = game.c config.c
GAME_HDR = game.h config.h
TRACE    = game_trace$(EXE)
REGS     = game_regs$(EXE)

.PHONY: pc check trace clean

pc: $(TRACE) $(REGS)

$(TRACE): trace_main.c $(GAME_SRC) $(GAME_HDR)
	$(CC) $(CFLAGS) -o $@ trace_main.c $(GAME_SRC) $(LDLIBS)

$(REGS): regs_main.c render_regs.c $(GAME_SRC) $(GAME_HDR) regs.h render_regs.h
	$(CC) $(CFLAGS) -o $@ regs_main.c render_regs.c $(GAME_SRC) $(LDLIBS)

trace: $(TRACE)
	$(PYTHON) ../../tools/trace_compare.py

check: pc
	$(PYTHON) ../../tools/gen_vhdl_assets.py --check
	$(PYTHON) ../../tools/game_model.py --selftest
	./$(REGS) --selftest
	$(PYTHON) ../../tools/trace_compare.py
	$(PYTHON) ../../tools/render_check.py

# Lewat Python agar jalan di PowerShell (tanpa rm) maupun Linux/WSL.
clean:
	$(PYTHON) -c "import os; [os.remove(f) for f in ('game_trace','game_trace.exe','game_regs','game_regs.exe') if os.path.exists(f)]"
