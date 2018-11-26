/* NUMA spinlock.  */

#ifndef _NUMA_SPINLOCK_H
#define _NUMA_SPINLOCK_H

#include <features.h>

__BEGIN_DECLS

struct numa_spinlock_node
{
  void *core;
  char __pad[64 - sizeof (void *)];
} __attribute__((aligned (64)));

struct numa_spinlock
{
  struct numa_spinlock_node owner;
  unsigned int node_count;
  struct numa_spinlock_node cpu[];
};

struct numa_spinlock_info
{
  struct numa_spinlock_info *next;
  void *(*workload) (void *);
  void *argument;
  void *result;
  unsigned int node;
  int pending;
  char __pad[64 - (4 * sizeof (void *) + 2 * sizeof (int))];
} __attribute__((aligned (64)));

extern struct numa_spinlock *init_numa_spinlock (void);
extern int init_numa_spinlock_info (struct numa_spinlock *,
				    struct numa_spinlock_info *);
extern void apply_numa_spinlock (struct numa_spinlock *,
				 struct numa_spinlock_info *);

__END_DECLS

#endif /* numa_spinlock.h */
