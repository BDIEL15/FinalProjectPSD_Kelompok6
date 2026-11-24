# Game Jump-to-Flap (C).
#   make pc        build alat uji untuk PC (Windows: mingw32-make pc)
#   make check     SEMUA uji: file generate, selftest, jejak Python vs C,
#                  register -> gambar, loop board (main.c) dengan platform PC
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
BSIM     = board_sim$(EXE)
PLATFORM = ../platform

.PHONY: pc check trace clean

pc: $(TRACE) $(REGS) $(BSIM)

$(TRACE): trace_main.c $(GAME_SRC) $(GAME_HDR)
	$(CC) $(CFLAGS) -o $@ trace_main.c $(GAME_SRC) $(LDLIBS)

$(REGS): regs_main.c render_regs.c $(GAME_SRC) $(GAME_HDR) regs.h render_regs.h
	$(CC) $(CFLAGS) -o $@ regs_main.c render_regs.c $(GAME_SRC) $(LDLIBS)

# main.c (loop board) + platform tiruan PC
BSIM_SRC = board_sim.c main.c render_regs.c game.c config_default.c $(PLATFORM)/platform_pc.c
$(BSIM): $(BSIM_SRC) game.h regs.h render_regs.h $(PLATFORM)/platform.h
	$(CC) $(CFLAGS) -DBOARD_SIM -o $@ $(BSIM_SRC)

trace: $(TRACE)
	$(PYTHON) ../../tools/trace_compare.py

check: pc
	$(PYTHON) ../../tools/gen_vhdl_assets.py --check
	$(PYTHON) ../../tools/gen_config_c.py --check
	$(PYTHON) ../../tools/game_model.py --selftest
	./$(REGS) --selftest
	$(PYTHON) ../../tools/trace_compare.py
	$(PYTHON) ../../tools/render_check.py
	./$(BSIM)

# Lewat Python agar jalan di PowerShell (tanpa rm) maupun Linux/WSL.
clean:
	$(PYTHON) -c "import os; [os.remove(f) for f in ('game_trace','game_trace.exe','game_regs','game_regs.exe','board_sim','board_sim.exe') if os.path.exists(f)]"
