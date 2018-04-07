/* Check compatibility of CET-enabled executable with dlopened legacy
   shared object.  Copied from gcc.target/i386/pr81128.c in GCC testsuite.
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

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

int resolver_fn = 0;
int resolved_fn = 0;

static inline void
do_it_right_at_runtime_A (void)
{
  resolved_fn++;
}

static inline void
do_it_right_at_runtime_B (void)
{
  resolved_fn++;
}

static inline void do_it_right_at_runtime (void);

void do_it_right_at_runtime (void)
  __attribute__ ((ifunc ("resolve_do_it_right_at_runtime")));

static void (*resolve_do_it_right_at_runtime (void)) (void)
{
  srand (time (NULL));
  int r = rand ();
  resolver_fn++;

  /* Use intermediate variable to get a warning for non-matching
   * prototype. */
  typeof(do_it_right_at_runtime) *func;
  if (r & 1)
    func = do_it_right_at_runtime_A;
  else
    func = do_it_right_at_runtime_B;

  return (void *) func;
}

int
test (void)
{
  const unsigned int ITERS = 10;

  for (int i = ITERS; i > 0; i--)
    {
      do_it_right_at_runtime ();
    }

  if (resolver_fn != 1)
    __builtin_abort ();

  if (resolved_fn != 10)
    __builtin_abort ();

  return 0;
}

#ifndef TEST_MODULE
static int
do_test (void)
{
  return test ();
}

#include <support/test-driver.c>
#endif
