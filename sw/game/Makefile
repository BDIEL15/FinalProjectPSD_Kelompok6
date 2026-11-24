# Game Jump-to-Flap (C).
#   make pc        build alat uji jejak untuk PC (Windows: mingw32-make pc)
#   make trace     build + bandingkan jejak dengan model Python
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
TRACE    = game_trace$(EXE)

.PHONY: pc trace clean

pc: $(TRACE)

$(TRACE): trace_main.c $(GAME_SRC) game.h config.h
	$(CC) $(CFLAGS) -o $@ trace_main.c $(GAME_SRC) $(LDLIBS)

trace: $(TRACE)
	$(PYTHON) ../../tools/trace_compare.py

clean:
	-rm -f game_trace game_trace.exe
