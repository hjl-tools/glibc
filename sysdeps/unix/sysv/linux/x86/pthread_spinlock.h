/* Functions for pthread_spinlock_t.  X86 version.
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

static __always_inline void
atomic_spin_lock (pthread_spinlock_t *lock, int *cnt_p, int max_cnt)
{
  int val = 0;
  int cnt = *cnt_p;
  do
    {
      atomic_spin_nop ();
      val = atomic_load_relaxed (lock);
    }
  while (val != 0 && ++cnt < max_cnt);
  *cnt_p = cnt;
}
