# Copyright 2010, The Native Client SDK Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can
# be found in the LICENSE file.

# Makefile for the Simple dynamic code generation example

.PHONY: all clean

DYNAMIC_CODE_SIZE = 0x30000

CFILES = myjit.c

NACL_SDK_ROOT = ../..

CFLAGS = -Wall -Wno-long-long -pthread -Werror
INCLUDES =
LDFLAGS = -lppruntime \
          -lpthread \
          -lplatform \
          -lgio \
          -lsrpc \
	  $(ARCH_FLAGS)
OPT_FLAGS = -O2
#	  -Wl,--section-start=.rodata=0x00070000 \

all: check_variables myjit_x86_32.nexe myjit_x86_64.nexe

# common.mk has rules to build .o files from .cc files.
-include ../common.mk

myjit.nmf: myjit_x86_32.nexe myjit_x86_64.nexe
	@echo "Creating hello_world.nmf..."
	$(PYTHON) ../generate_nmf.py --nmf $@ \
	 --x86-64 myjit_x86_64.nexe --x86-32 myjit_x86_32.nexe

# Have to link with g++: the implementation of the PPAPI proxy
# is a C++ implementation

myjit_x86_32.nexe: myjit_tmp.nexe
	ETEXT=0x$(shell sh -x -c "$(NACL_SDK_ROOT)/$(NACL_TOOLCHAIN_DIR)/bin/nacl-nm $< | awk -f get-etext.awk") $(MAKE) compile-myjit_32

myjit_x86_64.nexe: myjit_tmp.nexe
	ETEXT=0x$(shell sh -x -c "$(NACL_SDK_ROOT)/$(NACL_TOOLCHAIN_DIR)/bin/nacl-nm $< | awk -f get-etext.awk") $(MAKE) compile-myjit_64

clean:
	-$(RM) *.nmf *.o *.obj *.nexe

myjit_tmp.nexe: myjit.c
	$(CPP) $(CFLAGS) -DETEXT=0x400000 -DDYNAMIC_CODE_SIZE=$(DYNAMIC_CODE_SIZE) $(DEBUG_FLAGS) $(LDFLAGS) -o $@ $<

myjit.nexe: myjit_tmp.nexe
	ETEXT=0x$(shell sh -x -c "$(NACL_SDK_ROOT)/$(NACL_TOOLCHAIN_DIR)/bin/nacl-nm $< | awk -f get-etext.awk") $(MAKE) compile-myjit

compile-myjit_32:
	$(CPP) -m32 $(CFLAGS) -DETEXT=$(ETEXT) -DDYNAMIC_CODE_SIZE=$(DYNAMIC_CODE_SIZE) $(DEBUG_FLAGS) $(LDFLAGS) \
	  -Wl,--section-start=.rodata=$(shell sh -c "printf '0x%x' $$(($(ETEXT)+$(DYNAMIC_CODE_SIZE)))") \
	-o myjit_x86_32.nexe myjit.c

compile-myjit_64:
	$(CPP) -m64 $(CFLAGS) -DETEXT=$(ETEXT) -DDYNAMIC_CODE_SIZE=$(DYNAMIC_CODE_SIZE) $(DEBUG_FLAGS) $(LDFLAGS) \
	  -Wl,--section-start=.rodata=$(shell sh -c "printf '0x%x' $$(($(ETEXT)+$(DYNAMIC_CODE_SIZE)))") \
	-o myjit_x86_64.nexe myjit.c

# This target is used by the SDK build system to produce a pre-built version
# of the .nexe.  You do not need to call this target.
install_prebuilt: hello_world.nmf
	-$(RM) $(OBJECTS_X86_32) $(OBJECTS_X86_64)
