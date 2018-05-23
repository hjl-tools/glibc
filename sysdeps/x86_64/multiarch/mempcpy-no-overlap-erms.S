/* mempcpy with rep movsb.
   Copyright (C) 2018 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <http://www.gnu.org/licenses/>.  */

#include <sysdep.h>

ENTRY (__mempcpy_no_overlap_erms)
	leaq	(%rdi, %rdx), %rax
	/* Skip zero length.  */
	testq	%rdx, %rdx
	jz	L(nop)
	/* Source == destination is less common.  */
	cmpq	%rsi, %rdi
	je	L(nop)
	movq	%rdx, %rcx
	rep movsb
L(nop):
	ret
END (__mempcpy_no_overlap_erms)

