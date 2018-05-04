/* Check swapcontext wrapper.
   Modified from c-c++-common/asan/swapcontext-test-1.c in GCC testsuite.
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
#include <ucontext.h>
#include <unistd.h>

__attribute__((noinline, noclone))
int
myswapcontext (ucontext_t *oucp, ucontext_t *ucp)
{
  int res = swapcontext (oucp, ucp);
  return res;
}

ucontext_t orig_context;
ucontext_t child_context;

void
Child (int mode)
{
  char x[32] = {0};  /* Stack gets poisoned. */
  printf("Child: %p\n", x);
  /* (a) Do nothing, just return to parent function.
     (b) Jump into the original function. Stack remains poisoned unless we do
     something. */
  if (mode == 1)
    {
      if (myswapcontext (&child_context, &orig_context) < 0)
	{
	  perror ("swapcontext");
	  _exit (0);
	}
    }
}

int
Run (int arg, int mode)
{
  int i;
  const int kStackSize = 1 << 20;
  char child_stack[kStackSize + 1];
  printf ("Child stack: %p\n", child_stack);
  /* Setup child context. */
  getcontext (&child_context);
  child_context.uc_stack.ss_sp = child_stack;
  child_context.uc_stack.ss_size = kStackSize / 2;
  if (mode == 0)
    child_context.uc_link = &orig_context;
  makecontext (&child_context, (void (*)(void))Child, 1, mode);
  if (myswapcontext (&orig_context, &child_context) < 0)
    {
      perror("swapcontext");
      return 0;
    }
  /* Touch childs's stack to make sure it's unpoisoned. */
  for (i = 0; i < kStackSize; i++)
    child_stack[i] = i;
  return child_stack[arg];
}

volatile int zero = 0;

static int
do_test (void)
{
  int ret = 0;
  ret += Run (zero, 0);
  fprintf (stderr, "Test1 passed\n");
  ret += Run (zero, 1);
  fprintf (stderr, "Test2 passed\n");
  return ret;
}

#include <support/test-driver.c>
