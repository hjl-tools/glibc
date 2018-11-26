/* NUMA spinlock.  */

#ifndef _NUMA_SPINLOCK_H
#define _NUMA_SPINLOCK_H

#include <features.h>

__BEGIN_DECLS

struct numa_spinlock_queue_node
{
  void *core;
  char __pad[64 - sizeof (void *)];
} __attribute__((aligned (64)));

struct numa_spinlock_queue
{
  struct numa_spinlock_queue_node owner;
  struct numa_spinlock_queue_node cpu[];
};

struct numa_spinlock_queue_info
{
  struct numa_spinlock_queue_info *next;
  void *(*func) (void *);
  void *argument;
  void *value;
  unsigned int node;
  int pending;
  char __pad[64 - (4 * sizeof (void *) + 2 * sizeof (int))];
} __attribute__((aligned (64)));

extern struct numa_spinlock_queue *init_numa_spinlock_queue (void);
extern int init_numa_spinlock_queue_info
  (struct numa_spinlock_queue_info *);
extern int insert_numa_spinlock_queue (struct numa_spinlock_queue *,
				       struct numa_spinlock_queue_info *);

__END_DECLS

#endif /* numa_spinlock.h */
