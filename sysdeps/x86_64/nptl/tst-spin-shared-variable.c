/* Check spinlock overhead with large number threads.  Critical region is
   very smmall.  Critical region + spinlock overhead aren't noticeable 
   when number of threads is small.  When thread number increases,
   spinlock overhead become the bottleneck.  It shows up in wall time
   of thread execution.  */

#ifndef _GNU_SOURCE
# define _GNU_SOURCE
#endif
#include <unistd.h>
#include <stdio.h>
#include <pthread.h>
#include <sched.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <sys/param.h>
#include <errno.h>

#ifdef MODULE_NAME
static int do_test (void);
# define TIMEOUT 600
#include <support/test-driver.c>
#else
# define EXIT_UNSUPPORTED 77
#endif

#define memory_barrier() __asm ("" ::: "memory")
#define pause() __asm  ("rep ; nop" ::: "memory")

#define CACHELINE_SIZE	64
#define CACHE_ALIGNED	__attribute__((aligned(CACHELINE_SIZE)))

#define constant_time 5

unsigned long g_val CACHE_ALIGNED;
unsigned long g_val2 CACHE_ALIGNED;
unsigned long g_val3 CACHE_ALIGNED;
unsigned long cmplock CACHE_ALIGNED;

/* The time consumed by one update is about 20 nanoseconds.  */
static int delay_time_unlocked = 20;

struct
{
  pthread_spinlock_t testlock;
  char pad[64];
} test CACHE_ALIGNED;

#define lock() pthread_spin_lock(&test.testlock)
#define unlock() pthread_spin_unlock(&test.testlock)

static void
__attribute__((constructor))
init_spin (void)
{
  pthread_spin_init (&test.testlock, 0);
}

struct ops
{
  void *(*test) (void *arg);
  void (*aggregate) (void **, int);
} *ops;

struct stats_result
{
  unsigned long num;
};

void *work_thread (void *arg);
void aggregate (void **r, int num);

void test_threads (int numthreads, unsigned long time);

#define iterations (10000 * 5)

static volatile int start_thread;
static volatile int stop_flag;

static FILE *account_fh;

static void
__attribute__((constructor))
fh_init (void)
{
  account_fh = stdout;
}

static void
print_field (unsigned long num, const char *field)
{
  fprintf(account_fh, "%lu %s ", num, field);
}

void *
work_thread (void *arg)
{
  long i;
  unsigned long ret;
  struct stats_result *res;

  if (posix_memalign ((void **)&res, CACHELINE_SIZE,
		      roundup (sizeof (*res), CACHELINE_SIZE)) != 0)
    {
      printf ("memory allocation failure, %s\n", strerror (errno));
      exit (errno);
    }
  long num = 0;

  while (!start_thread)
    pause ();

  struct timespec ts =
    {
      .tv_sec = 0,
      .tv_nsec = delay_time_unlocked
    };

  for (i = 0; i < iterations; i++)
    {
      lock();

      g_val = g_val + 1;
      g_val2 = g_val2 + 1;
      ret = __sync_val_compare_and_swap (&cmplock, 0, 1);
      g_val3 = g_val3 + 1 + ret;

      unlock ();
      clock_nanosleep (CLOCK_MONOTONIC, 0, &ts, NULL);
      num++;
    }
  res->num = num;

  return res;
}

void
aggregate (void **r, int num)
{
  struct stats_result **res = (struct stats_result **)r;
  int i;
  unsigned long nlocks = 0;

  for (i = 0; i < num; i++)
    nlocks += res[i]->num;
  print_field (num, "threads");
  print_field (nlocks/num, "num");
  puts ("");
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
	  .tv_sec = time,
	  .tv_nsec = 0
	};
      clock_nanosleep (CLOCK_MONOTONIC, 0, &ts, NULL);
      memory_barrier ();
      stop_flag = 1;
    }

  for (i = 0; i < numthreads; i++)
    pthread_join (thr[i], (void *)&res[i]);

  ops->aggregate (res, numthreads);

  for (i = 0; i < numthreads; i++)
    free (res[i]);
}

struct ops hashwork_ops =
{
  .test = work_thread,
  .aggregate = aggregate,
};

struct ops *ops;

static unsigned long long
total_wall (int numthreads)
{
  struct timespec start, end, diff;
  clock_gettime (CLOCK_MONOTONIC, &start);
  test_threads (numthreads, constant_time);
  clock_gettime (CLOCK_MONOTONIC, &end);
  diff.tv_sec = end.tv_sec - start.tv_sec;
  diff.tv_nsec = end.tv_sec - start.tv_nsec;
  if (diff.tv_nsec < 0)
    {
       diff.tv_nsec += 1000000000;
       --diff.tv_sec;
    }
  return diff.tv_sec * 1000000000 + diff.tv_nsec;
}

#ifdef MODULE_NAME
static int
do_test (void)
#else
int
main ()
#endif
{
  int numthreads = sysconf (_SC_NPROCESSORS_ONLN);
  if (numthreads < 1)
    return EXIT_UNSUPPORTED;

  ops = &hashwork_ops;

  unsigned long long wall;
  int i, last;
  for (last = i = 1; i <= numthreads;)
    {
      wall = total_wall (i);
      printf ("wall time (%4d threads): %lld\n", i, wall);
      last = i;
      if (i < 32)
	i += i;
      else
	i += 16;
    }

  if (last != numthreads)
    {
      wall = total_wall (numthreads);
      printf ("wall time (%4d threads): %lld\n", numthreads, wall);
    }

  return EXIT_SUCCESS;
}
