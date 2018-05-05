/* The tunable framework for the CPU run-time library.
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

#ifndef	_CPU_RT_TUNABLES_H
#define	_CPU_RT_TUNABLES_H 1

#ifdef CPU_RT_TUNABLES
# define __tunables_init	__cpu_rt_tunables_init
# define __tunable_get_val	__cpu_rt_tunable_get_val
# define __tunable_set_val	__cpu_rt_tunable_set_val
#else
# define __tunables_init	__redirect___tunables_init
# define __tunable_get_val	__redirect___tunable_get_val
# define __tunable_set_val	__redirect___tunable_set_val
#endif

#include <elf/dl-tunables.h>

#ifdef CPU_RT_TUNABLES
extern void __cpu_rt_tunables_init (char **) attribute_hidden;
extern void __cpu_rt_tunable_get_val (tunable_id_t, void *,
				      tunable_callback_t)
  attribute_hidden;
extern void __cpu_rt_tunable_set_val (tunable_id_t, void *)
  attribute_hidden;
#else
# undef __tunables_init
# define __tunables_init	__cpu_rt_tunables_init
# undef __tunable_get_val
# define __tunable_get_val	__cpu_rt_tunable_get_val
# undef __tunable_set_val
# define __tunable_set_val	__cpu_rt_tunable_set_val

extern __typeof (__redirect___tunables_init) __cpu_rt_tunables_init
  attribute_hidden;
extern __typeof (__redirect___tunable_get_val) __cpu_rt_tunable_get_val
  attribute_hidden;
extern __typeof (__redirect___tunable_set_val) __cpu_rt_tunable_set_val
  attribute_hidden;
#endif

#endif
