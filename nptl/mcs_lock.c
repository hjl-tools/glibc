/* Copyright (C) 2018 Free Software Foundation, Inc.
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

#include "pthreadP.h"
#include <atomic.h>

static __thread mcs_lock_t node = {
	NULL,
	0,
};

void mcs_lock (mcs_lock_t **lock)
{
  mcs_lock_t *prev;

  /* Initalize node.  */
  node.next = NULL;
  node.locked = 0;

  prev = atomic_exchange_acquire(lock, &node);

  /* No spinners waiting in the queue, lock is acquired immediately.  */
  if (prev == NULL)
    {
      node.locked = 1;
      return;
    }

  /* Add current spinner into the queue.  */
  atomic_store_release (&prev->next, &node);
  atomic_full_barrier ();
  /* Waiting until waken up by the previous spinner.  */
  while (!atomic_load_relaxed (&node.locked))
    atomic_spin_nop ();
}

void mcs_unlock (mcs_lock_t **lock)
{
  mcs_lock_t *next = node.next;

  if (next == NULL)
    {
      /* Check the tail of the queue:
         a) Release the lock and return if current node is the tail.  */
      if (atomic_compare_and_exchange_val_acq(lock, NULL, &node) == &node)
        return;

      /* b) Waiting until new node is added to the queue if current node is
         not the tail (lock != node).  */
      while (! (next = atomic_load_relaxed (&node.next)))
        atomic_spin_nop ();
    }

  /* Wake up the next spinner.  */
  atomic_store_release (&next->locked, 1);
  atomic_full_barrier ();
}
