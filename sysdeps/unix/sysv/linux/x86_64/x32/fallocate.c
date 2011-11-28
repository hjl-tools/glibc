/* Copyright (C) 2011 Free Software Foundation, Inc.
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
   License along with the GNU C Library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
   02111-1307 USA.  */

#include <errno.h>
#include <fcntl.h>
#include <sysdep.h>
#include <sysdep-cancel.h>

#undef LOAD_ARGS_3
#define LOAD_ARGS_3(a1, a2, a3)				\
  long long int __arg3 = (long long int) (a3);		\
  LOAD_ARGS_2 (a1, a2)
#undef LOAD_REGS_3
#define LOAD_REGS_3					\
  register long long int _a3 asm ("rdx") = __arg3;	\
  LOAD_REGS_2

#undef LOAD_ARGS_4
#define LOAD_ARGS_4(a1, a2, a3, a4)			\
  long long int __arg4 = (long long int) (a4);		\
  LOAD_ARGS_3 (a1, a2, a3)
#undef LOAD_REGS_4
#define LOAD_REGS_4					\
  register long long int _a4 asm ("r10") = __arg4;	\
  LOAD_REGS_3

/* Reserve storage for the data of the file associated with FD.  */
int
fallocate (int fd, int mode, __off_t offset, __off_t len)
{
  if (SINGLE_THREAD_P)
    return INLINE_SYSCALL (fallocate, 4, fd, mode, offset, len);

  int oldtype = LIBC_CANCEL_ASYNC ();
  int result = INLINE_SYSCALL (fallocate, 4, fd, mode, offset, len);

  LIBC_CANCEL_RESET (oldtype);

  return result;
}
strong_alias (fallocate, fallocate64)
