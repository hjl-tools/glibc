/* Miscellaneous support functions for the CPU run-time library.  X86
   version.
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

#if HAVE_TUNABLES
# include <cpu-rt-c/cpu-rt-misc.c>
# include <cpu-tunables.c>
#else
# include <ldsodefs.h>
#endif
#include <cpu-features.c>
#include <dl-procinfo.c>

void
__cpu_rt_x86_init_cpu_features (void)
{
  /* Since IFUNC selector in the CPU run-time library may be called before
     dl_x86_cpu_features is initialized by DT_INIT_ARRAY with LD_PRELOAD
     on non-lazy binding shared objects, __cpu_rt_x86_init_cpu_features
     must be called from all IFUNC selectors.  Since dl_x86_cpu_features
     is hidden in the CPU run-time library, it can be accessed without
     dynamic relocations and we can skip calling init_cpu_features if
     not needed.  */
  if (GLRO(dl_x86_cpu_features).kind == arch_kind_unknown)
    init_cpu_features (&GLRO(dl_x86_cpu_features));
}

#if HAVE_TUNABLES
static void
cpu_rt_init (int argc __attribute__ ((unused)),
	     char **argv  __attribute__ ((unused)),
	     char **environ)
{
  __cpu_rt_x86_init_cpu_features ();
  __tunables_init (environ);
  init_cpu_features_tunables (&GLRO(dl_x86_cpu_features));
}

# ifdef SHARED
#  define INIT_SECTION ".init_array"
# else
#  define INIT_SECTION ".preinit_array"
# endif

static void (*const cpu_rt_init_array []) (int, char **, char **)
  __attribute__ ((used, section (INIT_SECTION), aligned (sizeof (void *)))) =
{
  &cpu_rt_init
};
#endif
