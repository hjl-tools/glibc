#ifndef _GNU_SOURCE
# define _GNU_SOURCE
#endif
#include <unistd.h>
#include <stdio.h>
#include <pthread.h>
#include <sched.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/time.h>
#include <sys/param.h>
#include <errno.h>
#include <numa-spinlock/numa-spinlock.h>

#define memory_barrier() __asm ("" ::: "memory")
#define pause() __asm  ("rep ; nop" ::: "memory")

#define CACHELINE_SIZE	64
#define CACHE_ALIGNED	__attribute__((aligned(CACHELINE_SIZE)))

#define constant_time 5
unsigned long g_val CACHE_ALIGNED;
unsigned long g_val2 CACHE_ALIGNED;
unsigned long g_val3 CACHE_ALIGNED;
unsigned long cmplock CACHE_ALIGNED;
struct count
{
  unsigned long long total;
  unsigned long long spinlock;
  unsigned long long wall;
} __attribute__((aligned(128)));

struct count *gcount;

/* The time consumed by one update is about 200 TSCs.  */
static int delay_time_unlocked = 400;

struct numa_spinlock_queue *queue;

struct ops
{
  void *(*test) (void *arg);
  void (*print_thread) (void *res, int);
} *ops;

struct stats_result
{
  unsigned long num;
};

void *work_thread (void *arg);

void test_threads (int numthreads, unsigned long time);

#define iterations (10000 * 5)

static volatile int start_thread;
static volatile int stop_flag;


/* Delay some fixed time */
static void
delay_tsc (unsigned n)
{
  unsigned long long start, current, diff;
  unsigned int aux;
  start = __builtin_ia32_rdtscp (&aux);
  while (1)
    {
      current = __builtin_ia32_rdtscp (&aux);
      diff = current - start;
      if (diff < n)
	pause ();
      else
	break;
    }
}

static void
wait_a_bit (int delay_time)
{
  if (delay_time > 0)
    delay_tsc (delay_time);
}

struct work_todo_argument
{
  unsigned long *v1;
  unsigned long *v2;
  unsigned long *v3;
  unsigned long *v4;
};

static void *
work_todo (void *v)
{
  struct work_todo_argument *p = v;
  unsigned long ret;
  *p->v1 = *p->v1 + 1;
  *p->v2 = *p->v2 + 1;
  ret = __sync_val_compare_and_swap (p->v4, 0, 1);
  *p->v3 = *p->v3 + ret;
  return (void *) 2;
}

void *
work_thread (void *arg)
{
  long i;
  unsigned long pid = (unsigned long) arg;
  struct stats_result *res;
  unsigned long long start, end;
  struct work_todo_argument work_todo_arg;
  struct numa_spinlock_queue_info queue_info;

  int err_ret = posix_memalign ((void **)&res, CACHELINE_SIZE,
				roundup (sizeof (*res), CACHELINE_SIZE));
  if (err_ret)
    {
      printf ("posix_memalign failure: %s\n", strerror (err_ret));
      exit (err_ret);
    }

  if (init_numa_spinlock_queue_info (&queue_info))
    {
      printf ("init_numa_spinlock_queue_info failure: %m\n");
      exit (1);
    }

  long num = 0;

  work_todo_arg.v1 = &g_val;
  work_todo_arg.v2 = &g_val2;
  work_todo_arg.v3 = &g_val3;
  work_todo_arg.v4 = &cmplock;
  queue_info.argument = &work_todo_arg;
  queue_info.func = work_todo;

  while (!start_thread)
    pause ();

  unsigned int aux;
  start = __builtin_ia32_rdtscp (&aux);
  for (i = 0; i < iterations; i++)
    {
      insert_numa_spinlock_queue (queue, &queue_info);
      wait_a_bit (delay_time_unlocked);
      num++;
    }
  end = __builtin_ia32_rdtscp (&aux);
  gcount[pid].total = end - start;
  res->num = num;

  return res;
}


void
init_global_data(void)
{
  g_val = 0;
  g_val2 = 0;
  g_val3 = 0;
  cmplock = 0;
}

void
test_threads (int numthreads, unsigned long time)
{
  start_thread = 0;
  stop_flag = 0;

  queue = init_numa_spinlock_queue ();
  memory_barrier ();

  pthread_t thr[numthreads];
  void *res[numthreads];
  int i;

  init_global_data ();
  for (i = 0; i < numthreads; i++)
    {
      pthread_attr_t attr;
      pthread_attr_init (&attr);
      cpu_set_t set;
      CPU_ZERO (&set);
      (void)CPU_SET (i, &set);
      pthread_attr_setaffinity_np (&attr, sizeof(cpu_set_t), &set);
      pthread_create (&thr[i], &attr, ops->test, (void *)(long)i);
    }

  memory_barrier ();
  start_thread = 1;
  memory_barrier ();
  sched_yield ();

  if (time)
    {
      struct timespec ts =
	{
	  ts.tv_sec = time,
	  ts.tv_nsec = 0
	};
      clock_nanosleep (CLOCK_MONOTONIC, 0, &ts, NULL);
      memory_barrier ();
      stop_flag = 1;
    }

  for (i = 0; i < numthreads; i++) {
    pthread_join (thr[i], (void *)&res[i]);
    free (res[i]);
  }

}

struct ops hashwork_ops =
{
  .test = work_thread,
};

struct ops *ops;

static struct count
total_cost (int numthreads)
{
  int i;
  unsigned long long total = 0;
  unsigned long long spinlock = 0;

  memset (gcount, 0, sizeof(gcount[0]) * numthreads);

  unsigned long long start, end, diff;
  unsigned int aux;

  start = __builtin_ia32_rdtscp (&aux);
  test_threads (numthreads, constant_time);
  end = __builtin_ia32_rdtscp (&aux);
  diff = end - start;

  for (i = 0; i < numthreads; i++)
    {
      total += gcount[i].total;
      spinlock += gcount[i].spinlock;
    }

  struct count cost = { total, spinlock, diff };
  return cost;
}

int
main (void)
{
  int numthreads = sysconf (_SC_NPROCESSORS_ONLN);
  if (numthreads < 8)
    return 1;

  ops = &hashwork_ops;

  int err_ret = posix_memalign ((void **)&gcount, 4096,
				sizeof(gcount[0]) * numthreads);
  if (err_ret)
    {
      printf ("posix_memalign failure: %s\n", strerror (err_ret));
      exit (err_ret);
    }

  struct count cost, cost1;
  double overhead;
  int i, last;
  cost1 = total_cost (1);
  for (last = i = 2; i <= numthreads;) 
    {
      last = i;
      cost = total_cost (i);
      overhead = cost.total;
      overhead /= i;
      overhead /= cost1.total;
      printf ("Number of threads: %4d, Total time %14lld, Overhead: %.2f\n",
	      i, cost.total, overhead);
      if ((i * 2) < numthreads)
	i = i * 2;
      else
	i = i + 16;
    }

  if (last != numthreads)
    {
      i = numthreads;
      cost = total_cost (i);
      overhead = cost.total;
      overhead /= i;
      overhead /= cost1.total;
      printf ("Number of threads: %4d, Total time %14lld, Overhead: %.2f\n",
	      i, cost.total, overhead);
    }

  free (gcount);
  return 0;
}
