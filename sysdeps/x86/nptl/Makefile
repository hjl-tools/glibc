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

ifeq ($(subdir),numa-spinlock)
libnuma_spinlock-tests += tst-spinlock-overhead \
			  tst-numa-spinlock-overhead \
			  tst-spinlock-hashwork-overhead \
			  tst-numa-spinlock-hashwork-overhead

ifeq (yes,$(build-shared))
$(addprefix $(objpfx),$(libnuma_spinlock-tests)): $(shared-thread-library)
else
$(addprefix $(objpfx),$(libnuma_spinlock-tests)): $(static-thread-library)
endif
endif
