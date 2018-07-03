/* pthread_mutex_conf.h: Pthread mutex tunable parameters.
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
#ifndef _PTHREAD_MUTEX_CONF_H
#define _PTHREAD_MUTEX_CONF_H 1

struct mutex_config
{
  int spin_count;
};

extern struct mutex_config __mutex_aconf attribute_hidden;

void mutex_tunables_init (void);

/* Adaptive mutex definitions.  */
#ifndef MAX_ADAPTIVE_COUNT
# if HAVE_TUNABLES
#  define MAX_ADAPTIVE_COUNT __mutex_aconf.spin_count
# else
#  define MAX_ADAPTIVE_COUNT 100
# endif
#endif

#endif
