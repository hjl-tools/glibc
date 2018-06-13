# Copyright (C) 2018 Free Software Foundation, Inc.
# This file is part of the GNU C Library.

# The GNU C Library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.

# The GNU C Library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

# You should have received a copy of the GNU Lesser General Public
# License along with the GNU C Library; if not, see
# <http://www.gnu.org/licenses/>.

# Makefile for the CPU run-time library for C.

subdir		:= cpu-rt-c

include ../Makeconfig

ifeq ($(build-cpu-rt),yes)
extra-libs	:= libcpu-rt-c
extra-libs-others = $(extra-libs)

libcpu-rt-c-sysdep_routines += $(cpu-rt-c-routines)
libcpu-rt-c-tests += $(addprefix test-,$(cpu-rt-c-routines))
tests += $(libcpu-rt-c-tests)

ifeq ($(build-shared),yes)
check-abi: $(objpfx)check-abi-libcpu-rt-c.out
tests-special += $(objpfx)check-abi-libcpu-rt-c.out
update-abi: update-abi-libcpu-rt-c
update-all-abi: update-all-abi-libcpu-rt-c
endif
endif

include ../Rules

ifeq ($(build-cpu-rt),yes)
ifeq ($(build-shared),yes)
libcpu-rt-c = $(objpfx)libcpu-rt-c.so
else
libcpu-rt-c = $(objpfx)libcpu-rt-c.a
endif
$(addprefix $(objpfx),$(libcpu-rt-c-tests)): $(libcpu-rt-c)
endif
