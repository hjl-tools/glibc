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

# Makefile for the numa spinlock library.

subdir		:= numa-spinlock

include ../Makeconfig

ifeq ($(build-libnuma_spinlock),yes)
extra-libs	:= libnuma_spinlock
extra-libs-others = $(extra-libs)

numa-spinlock-routines = numa-spinlock getmaxnumanode

libnuma_spinlock-sysdep_routines += $(numa-spinlock-routines)
libnuma_spinlock-tests += 
tests += $(libnuma_spinlock-tests)

ifeq ($(build-shared),yes)
check-abi: $(objpfx)check-abi-libnuma_spinlock.out
tests-special += $(objpfx)check-abi-libnuma_spinlock.out
update-abi: update-abi-libnuma_spinlock
update-all-abi: update-all-abi-libnuma_spinlock
endif
endif

include ../Rules

ifeq ($(build-shared),yes)
libnuma_spinlock = $(objpfx)libnuma_spinlock.so
else
libnuma_spinlock = $(objpfx)libnuma_spinlock.a
endif
$(addprefix $(objpfx),$(libnuma_spinlock-tests)): $(libnuma_spinlock)
