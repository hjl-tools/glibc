/* Get the maxinum NUMA node number, Linux version.
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

#include <assert.h>
#include <ctype.h>
#include <time.h>
#include <string.h>
#include <atomic.h>
#include <not-cancel.h>

#include "getmaxnumanode.h"

static char *
next_line (int fd, char *const buffer, char **cp, char **re,
	   char *const buffer_end)
{
  char *res = *cp;
  char *nl = memchr (*cp, '\n', *re - *cp);
  if (nl == NULL)
    {
      if (*cp != buffer)
	{
	  if (*re == buffer_end)
	    {
	      memmove (buffer, *cp, *re - *cp);
	      *re = buffer + (*re - *cp);
	      *cp = buffer;

	      ssize_t n = __read_nocancel (fd, *re, buffer_end - *re);
	      if (n < 0)
		return NULL;

	      *re += n;

	      nl = memchr (*cp, '\n', *re - *cp);
	      while (nl == NULL && *re == buffer_end)
		{
		  /* Truncate too long lines.  */
		  *re = buffer + 3 * (buffer_end - buffer) / 4;
		  n = __read_nocancel (fd, *re, buffer_end - *re);
		  if (n < 0)
		    return NULL;

		  nl = memchr (*re, '\n', n);
		  **re = '\n';
		  *re += n;
		}
	    }
	  else
	    nl = memchr (*cp, '\n', *re - *cp);

	  res = *cp;
	}

      if (nl == NULL)
	nl = *re - 1;
    }

  *cp = nl + 1;
  assert (*cp <= *re);

  return res == *re ? NULL : res;
}

int
__get_max_numa_node (void)
{
  static int cached_result = -1;
  static time_t timestamp;

  time_t now = time (NULL);
  time_t prev = timestamp;
  atomic_read_barrier ();
  if (now == prev && cached_result > -1)
    return cached_result;

  const size_t buffer_size = 1024;
  char buffer[buffer_size];
  char *buffer_end = buffer + buffer_size;
  char *cp = buffer_end;
  char *re = buffer_end;

  const int flags = O_RDONLY | O_CLOEXEC;
  int fd = __open_nocancel ("/sys/devices/system/node/online", flags);
  char *l;
  int result = 0;
  if (fd != -1)
    {
      l = next_line (fd, buffer, &cp, &re, buffer_end);
      if (l != NULL)
	do
	  {
	    char *endp;
	    unsigned long int n = strtoul (l, &endp, 10);
	    if (l == endp)
	      {
		result = 0;
		break;
	      }

	    unsigned long int m = n;
	    if (*endp == '-')
	      {
		l = endp + 1;
		m = strtoul (l, &endp, 10);
		if (l == endp)
		  {
		    result = 0;
		    break;
		  }
	      }

	    result += m - n + 1;

	    l = endp;
	    while (l < re && isspace (*l))
	      ++l;
	  }
	while (l < re);

      __close_nocancel_nostatus (fd);
    }

  if (!result)
    result = 1;

  cached_result = result;
  atomic_write_barrier ();
  timestamp = now;

  return result;
}
