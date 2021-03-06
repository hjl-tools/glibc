/* Copyright (C) 2002-2020 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Ulrich Drepper <drepper@redhat.com>, 2002.

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
   <https://www.gnu.org/licenses/>.  */

	.globl	pthread_spin_unlock
	.type	pthread_spin_unlock,@function
	.align	16
pthread_spin_unlock:
	movl	4(%esp), %eax
	movl	$1, (%eax)
	xorl	%eax, %eax
	ret
	.size	pthread_spin_unlock,.-pthread_spin_unlock

	/* The implementation of pthread_spin_init is identical.  */
	.globl	pthread_spin_init
pthread_spin_init = pthread_spin_unlock
