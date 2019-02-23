/* Check compatibility of CET-enabled executable with dlopened legacy
   shared object.
   Copyright (C) 2019 Free Software Foundation, Inc.
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

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <support/check.h>

static void
do_test_1 (const char *modname, bool fail)
{
  int (*fp) (void);
  void *h;

  h = dlopen (modname, RTLD_LAZY);
  if (h == NULL)
    {
      if (fail)
	{
	  const char *err = dlerror ();
	  if (strstr (err, "shadow stack isn't enabled") == NULL)
	    FAIL_EXIT1 ("incorrect dlopen '%s' error: %s\n", modname,
			dlerror ());
	  return;
	}

      FAIL_EXIT1 ("cannot open '%s': %s\n", modname, dlerror ());
    }

  fp = dlsym (h, "test");
  if (fp == NULL)
    FAIL_EXIT1 ("cannot get symbol 'test': %s\n", dlerror ());

  if (fp () != 0)
    FAIL_EXIT1 ("test () != 0");

  dlclose (h);
}

static int
do_test (void)
{
  do_test_1 ("tst-cet-legacy-mod-5a.so", true);
  do_test_1 ("tst-cet-legacy-mod-5b.so", false);
  return 0;
}

#include <support/test-driver.c>
