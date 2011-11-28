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
#include <signal.h>
#include <time.h>
#include <sys/poll.h>
#include <sysdep-cancel.h>


int
__pselect (int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds,
	   const struct timespec *timeout, const sigset_t *sigmask)
{
  /* The Linux kernel can in some situations update the timeout value.
     We do not want that so use a local variable.  */
  struct timespec tval;
  if (timeout != NULL)
    {
      tval = *timeout;
      timeout = &tval;
    }

  /* Note: the system call expects 7 values but on most architectures
     we can only pass in 6 directly.  If there is an architecture with
     support for more parameters a new version of this file needs to
     be created.  */
  struct
  {
    const sigset_t *ss;
    unsigned long long ss_len;
  } data;

  data.ss = sigmask;
  data.ss_len = _NSIG / 8;

  int result;

  if (SINGLE_THREAD_P)
    result = INLINE_SYSCALL (pselect6, 6, nfds, readfds, writefds,
			     exceptfds, timeout, &data);
  else
    {
      int oldtype = LIBC_CANCEL_ASYNC ();

      result = INLINE_SYSCALL (pselect6, 6, nfds, readfds, writefds,
			       exceptfds, timeout, &data);

      LIBC_CANCEL_RESET (oldtype);
    }

  return result;
}
weak_alias (__pselect, pselect)
strong_alias (__pselect, __libc_pselect)
