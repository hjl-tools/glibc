/* Test cases for x86 conversion functions between TSCs and nanoseconds.
   Copyright (C) 2015-2018 Free Software Foundation, Inc.
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

#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <x86intrin.h>
#include <sys/platform/x86.h>

static int do_test (void);

#include <support/test-driver.c>

static int
do_test (void)
{
  if (!CPU_FEATURE_USABLE (TSC_To_NS))
    return EXIT_UNSUPPORTED;

  unsigned long long start_tscs, end_tscs, diff_tscs;
  unsigned long long diff_nanoseconds;
  start_tscs = _rdtsc ();
  end_tscs = _rdtsc ();
  diff_tscs = end_tscs - start_tscs;
  diff_nanoseconds = x86_tsc_to_ns (diff_tscs);

  printf ("Diff: %lld (TSCs) -> %lld (nanoseconds)\n",
	  diff_tscs, diff_nanoseconds);

  diff_tscs = x86_ns_to_tsc (diff_nanoseconds);

  printf ("Diff: %lld (nanoseconds) -> %lld (TSCs)\n",
	  diff_nanoseconds, diff_tscs);

  return EXIT_SUCCESS;
}
