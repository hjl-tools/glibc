/* Support header file for the CPU run-time library.
   This file is part of the GNU C Library.
   Copyright (C) 2018 Free Software Foundation, Inc.

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

#ifndef	_CPU_RT_SUPPORT_H
#define	_CPU_RT_SUPPORT_H 1

/* It is safe to use the CPU run-time library with AT_SECURE and SUID
   binaries.  */
#define __libc_enable_secure __redirect___libc_enable_secure
#include <stdint.h>
#include <unistd.h>
#undef __libc_enable_secure
#define __libc_enable_secure 0

#ifdef CPU_RT_MISC
# define _dl_strtoul __cpu_rt_strtoul
#else
extern uint64_t __cpu_rt_strtoul (const char *, char **)
  attribute_hidden;
# define _dl_strtoul(nptr, endptr) __cpu_rt_strtoul ((nptr), (endptr))
#endif

#endif
