#include <string.h>
#include <stdlib.h>
#include <sched.h>
#include <errno.h>
#include <atomic.h>
#include "numa-spinlock.h"
#include "getmaxnumanode.h"

static inline void
run_numa_spinlock (struct numa_spinlock_info *old, void **cpu)
{
  struct numa_spinlock_info *next, *current;

  old->result = old->workload (old->argument);

retry:
  current = __sync_val_compare_and_swap (cpu, old, NULL);

  if (current == old)
    {
      atomic_store_release (&current->pending, 0);
      return;
    }

  current = atomic_exchange_acquire (cpu, old);

repeat:
  if (old == current)
    goto retry;

  while (!(next = atomic_load_relaxed (&current->next)))
    atomic_spin_nop ();

  current->result = current->workload (current->argument);
  current->pending = 0;
  current = next;
  goto repeat;
}

void
apply_numa_spinlock (struct numa_spinlock *lock,
		     struct numa_spinlock_info *current)
{
  struct numa_spinlock_info *old;
  void **core;

  current->next = NULL;
  current->pending = 1;
  core = &lock->cpu[current->node].core;
  old = atomic_exchange_acquire (core , current);
  if (old)
    {
      atomic_store_release (&current->next, old);
      while (atomic_load_relaxed (&current->pending))
	atomic_spin_nop ();
      return;
    }

  old = atomic_exchange_acquire (&lock->owner.core, current);
  if (old)
    {
      atomic_store_release (&old->next, current);
      while (atomic_load_relaxed (&current->pending))
	atomic_spin_nop ();
    }

  run_numa_spinlock (current, core);
  old = current;

  current = __sync_val_compare_and_swap (&lock->owner.core, old, NULL);
  if (current == old)
    return;

  while (!(current = atomic_load_relaxed (&old->next)))
    atomic_spin_nop ();

  atomic_store_release (&current->pending, 0);
}

int
init_numa_spinlock_info (struct numa_spinlock *lock,
			 struct numa_spinlock_info *info)
{
  memset (info, 0, sizeof (*info));
  unsigned int node;
  int err_ret = getcpu (NULL, &node);
  if (err_ret)
    return err_ret;
  if (node >= lock->node_count)
    {
      errno = EINVAL;
      return -1;
    }
  info->node = node;
  return err_ret;
}

struct numa_spinlock *
init_numa_spinlock (void)
{
  unsigned int node_count = __get_max_numa_node ();
  size_t size = (sizeof (struct numa_spinlock)
		 + node_count * sizeof (struct numa_spinlock_node));
  struct numa_spinlock *lock;
  if (posix_memalign ((void **) &lock, 64, size))
    return NULL;
  memset (lock, 0, size);
  lock->node_count = node_count;
  return lock;
}
