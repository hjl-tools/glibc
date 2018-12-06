#include <string.h>
#include <stdlib.h>
#include <sched.h>
#include <errno.h>
#include <atomic.h>
#include "numa-spinlock.h"
#include "getmaxnumanode.h"

static inline void
run_numa_spinlock_queue (struct numa_spinlock_queue_info *old, void **cpu)
{
  struct numa_spinlock_queue_info *next, *current;

  old->value = old->func (old->argument);

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

  current->value = current->func (current->argument);
  current->pending = 0;
  current = next;
  goto repeat;
}

void
insert_numa_spinlock_queue (struct numa_spinlock_queue *queue,
			    struct numa_spinlock_queue_info *current)
{
  struct numa_spinlock_queue_info *old;
  void **core;

  current->next = NULL;
  current->pending = 1;
  core = &queue->cpu[current->node].core;
  old = atomic_exchange_acquire (core , current);
  if (old)
    {
      atomic_store_release (&current->next, old);
      while (atomic_load_relaxed (&current->pending))
	atomic_spin_nop ();
      return;
    }

  old = atomic_exchange_acquire (&queue->owner.core, current);
  if (old)
    {
      atomic_store_release (&old->next, current);
      while (atomic_load_relaxed (&current->pending))
	atomic_spin_nop ();
    }

  run_numa_spinlock_queue (current, core);
  old = current;

  current = __sync_val_compare_and_swap (&queue->owner.core, old, NULL);
  if (current == old)
    return;

  while (!(current = atomic_load_relaxed (&old->next)))
    atomic_spin_nop ();

  atomic_store_release (&current->pending, 0);
}

int
init_numa_spinlock_queue_info (struct numa_spinlock_queue *queue,
			       struct numa_spinlock_queue_info *info)
{
  memset (info, 0, sizeof (*info));
  int err_ret = getcpu (NULL, &info->node);
  if (err_ret)
    return err_ret;
  if (info->node >= queue->node_count)
    {
      errno = EINVAL;
      return -1;
    }
  return err_ret;
}

struct numa_spinlock_queue *
init_numa_spinlock_queue (void)
{
  unsigned int node_count = __get_max_numa_node ();
  size_t size = (sizeof (struct numa_spinlock_queue)
		 + node_count * sizeof (struct numa_spinlock_queue_node));
  struct numa_spinlock_queue *queue;
  if (posix_memalign ((void **) &queue, 64, size))
    return NULL;
  memset (queue, 0, size);
  queue->node_count = node_count;
  return queue;
}
