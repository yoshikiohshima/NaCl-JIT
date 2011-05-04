# Copyright 2010, The Native Client SDK Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can
# be found in the LICENSE file.

# Makefile for the Simple dynamic code generation example

.PHONY: all clean

CFILES = 

NACL_SDK_ROOT = ../..

CFLAGS = -Wall -Wno-long-long -pthread -Werror
INCLUDES =
LDFLAGS = \
          -lpthread \
          -lplatform \
          -lgio \
	  -Wl,--section-start=.rodata=0x00070000 \
	  $(ARCH_FLAGS)
OPT_FLAGS = -O2

all: check_variables myjit.nmf myjit_dbg.nmf

# common.mk has rules to build .o files from .cc files.
-include ../common.mk

myjit.nmf: myjit_x86_32.nexe myjit_x86_64.nexe
	@echo "Creating hello_world.nmf..."
	$(PYTHON) ../generate_nmf.py --nmf $@ \
	 --x86-64 myjit_x86_64.nexe --x86-32 myjit_x86_32.nexe

myjit_dbg.nmf: myjit_x86_32_dbg.nexe myjit_x86_64_dbg.nexe
	@echo "Creating hello_world_dbg.nmf..."
	$(PYTHON) ../generate_nmf.py --nmf $@ \
	 --x86-64 myjit_x86_64_dbg.nexe \
	 --x86-32 myjit_x86_32_dbg.nexe

# Have to link with g++: the implementation of the PPAPI proxy
# is a C++ implementation

myjit_x86_32.nexe: $(OBJECTS_X86_32)
	$(CPP) $^ $(LDFLAGS) -m32 -o $@

myjit_x86_64.nexe: $(OBJECTS_X86_64)
	$(CPP) $^ $(LDFLAGS) -m64 -o $@

myjit_x86_32_dbg.nexe: $(OBJECTS_X86_32_DBG)
	$(CPP) $^ $(LDFLAGS) -m32 -o $@

myjit_x86_64_dbg.nexe: $(OBJECTS_X86_64_DBG)
	$(CPP) $^ $(LDFLAGS) -m64 -o $@

clean:
	-$(RM) *.nmf *.o *.obj *.nexe

myjit.nexe: myjit.c
	$(CC) $(CFLAGS) $(DEBUG_FLAGS) $(LDFLAGS) -o $@ $<


# This target is used by the SDK build system to produce a pre-built version
# of the .nexe.  You do not need to call this target.
install_prebuilt: hello_world.nmf
	-$(RM) $(OBJECTS_X86_32) $(OBJECTS_X86_64)
