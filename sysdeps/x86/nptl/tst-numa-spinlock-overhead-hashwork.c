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

struct count
{
  unsigned long long total;
} __attribute__((aligned(128)));

struct count *gcount;

/* The time consumed by one update is about 200 TSCs.  */
static int delay_time_unlocked = 400;

struct numa_spinlock_queue *queue;

#define HASHBUF 20

struct SHA1_CTX
{
    uint32_t state[5];
    uint32_t count[2];
    uint8_t  buffer[64];
};

typedef struct SHA1_CTX SHA1_CTX;

struct ops
{
  void *(*test) (void *arg);
} *ops;

void *work_thread (void *arg);

void test_threads (int numthreads);

#define iterations (10000 * 5)

static volatile int start_thread;

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

/* Hashwork */
/* SHA-1 in C, By Steve Reid <sreid@sea-to-sky.net> 100% Public Domain.  */

#define rol rotl32
static inline __attribute__((always_inline)) uint32_t rotl32 ( uint32_t x, int8_t r )
{
	  return (x << r) | (x >> (32 - r));
}
/* blk0() and blk() perform the initial expand. */
/* I got the idea of expanding during the round function from SSLeay */
/* FIXME: can we do this in an endian-proof way? */

#ifdef WORDS_BIGENDIAN
#define blk0(i) block->l[i]
#else
#define blk0(i) (block->l[i] = (rol(block->l[i],24)&0xFF00FF00) | (rol(block->l[i],8)&0x00FF00FF))
#endif
#define blk(i) (block->l[i&15] = rol(block->l[(i+13)&15]^block->l[(i+8)&15] ^ block->l[(i+2)&15]^block->l[i&15],1))

/* (R0+R1), R2, R3, R4 are the different operations used in SHA1 */
#define R0(v,w,x,y,z,i) z+=((w&(x^y))^y)+blk0(i)+0x5A827999+rol(v,5);w=rol(w,30);
#define R1(v,w,x,y,z,i) z+=((w&(x^y))^y)+blk(i)+0x5A827999+rol(v,5);w=rol(w,30);
#define R2(v,w,x,y,z,i) z+=(w^x^y)+blk(i)+0x6ED9EBA1+rol(v,5);w=rol(w,30);
#define R3(v,w,x,y,z,i) z+=(((w|x)&y)|(w&x))+blk(i)+0x8F1BBCDC+rol(v,5);w=rol(w,30);
#define R4(v,w,x,y,z,i) z+=(w^x^y)+blk(i)+0xCA62C1D6+rol(v,5);w=rol(w,30);

/* Hash a single 512-bit block. This is the core of the algorithm. */
static void SHA1_Transform(uint32_t state[5], const uint8_t buffer[64])
{
    uint32_t a, b, c, d, e;
    typedef union {
        uint8_t c[64];
        uint32_t l[16];
    } CHAR64LONG16;
    CHAR64LONG16* block;

    block = (CHAR64LONG16*)buffer;

    /* Copy context->state[] to working vars */
    a = state[0];
    b = state[1];
    c = state[2];
    d = state[3];
    e = state[4];

    /* 4 rounds of 20 operations each. Loop unrolled. */
    R0(a,b,c,d,e, 0); R0(e,a,b,c,d, 1); R0(d,e,a,b,c, 2); R0(c,d,e,a,b, 3);
    R0(b,c,d,e,a, 4); R0(a,b,c,d,e, 5); R0(e,a,b,c,d, 6); R0(d,e,a,b,c, 7);
    R0(c,d,e,a,b, 8); R0(b,c,d,e,a, 9); R0(a,b,c,d,e,10); R0(e,a,b,c,d,11);
    R0(d,e,a,b,c,12); R0(c,d,e,a,b,13); R0(b,c,d,e,a,14); R0(a,b,c,d,e,15);
    R1(e,a,b,c,d,16); R1(d,e,a,b,c,17); R1(c,d,e,a,b,18); R1(b,c,d,e,a,19);
    R2(a,b,c,d,e,20); R2(e,a,b,c,d,21); R2(d,e,a,b,c,22); R2(c,d,e,a,b,23);
    R2(b,c,d,e,a,24); R2(a,b,c,d,e,25); R2(e,a,b,c,d,26); R2(d,e,a,b,c,27);
    R2(c,d,e,a,b,28); R2(b,c,d,e,a,29); R2(a,b,c,d,e,30); R2(e,a,b,c,d,31);
    R2(d,e,a,b,c,32); R2(c,d,e,a,b,33); R2(b,c,d,e,a,34); R2(a,b,c,d,e,35);
    R2(e,a,b,c,d,36); R2(d,e,a,b,c,37); R2(c,d,e,a,b,38); R2(b,c,d,e,a,39);
    R3(a,b,c,d,e,40); R3(e,a,b,c,d,41); R3(d,e,a,b,c,42); R3(c,d,e,a,b,43);
    R3(b,c,d,e,a,44); R3(a,b,c,d,e,45); R3(e,a,b,c,d,46); R3(d,e,a,b,c,47);
    R3(c,d,e,a,b,48); R3(b,c,d,e,a,49); R3(a,b,c,d,e,50); R3(e,a,b,c,d,51);
    R3(d,e,a,b,c,52); R3(c,d,e,a,b,53); R3(b,c,d,e,a,54); R3(a,b,c,d,e,55);
    R3(e,a,b,c,d,56); R3(d,e,a,b,c,57); R3(c,d,e,a,b,58); R3(b,c,d,e,a,59);
    R4(a,b,c,d,e,60); R4(e,a,b,c,d,61); R4(d,e,a,b,c,62); R4(c,d,e,a,b,63);
    R4(b,c,d,e,a,64); R4(a,b,c,d,e,65); R4(e,a,b,c,d,66); R4(d,e,a,b,c,67);
    R4(c,d,e,a,b,68); R4(b,c,d,e,a,69); R4(a,b,c,d,e,70); R4(e,a,b,c,d,71);
    R4(d,e,a,b,c,72); R4(c,d,e,a,b,73); R4(b,c,d,e,a,74); R4(a,b,c,d,e,75);
    R4(e,a,b,c,d,76); R4(d,e,a,b,c,77); R4(c,d,e,a,b,78); R4(b,c,d,e,a,79);

    /* Add the working vars back into context.state[] */
    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;

    /* Wipe variables */
    a = b = c = d = e = 0;
}

/* SHA1Init - Initialize new context */
static void SHA1_Init(SHA1_CTX* context)
{
    /* SHA1 initialization constants */
    context->state[0] = 0x67452301;
    context->state[1] = 0xEFCDAB89;
    context->state[2] = 0x98BADCFE;
    context->state[3] = 0x10325476;
    context->state[4] = 0xC3D2E1F0;
    context->count[0] = 0;
  	context->count[1] = 0;
}

/* Run your data through this. */
void SHA1_Update(SHA1_CTX* context, const uint8_t* data, const size_t len)
{
    size_t i, j;

    j = (context->count[0] >> 3) & 63;
    if ((context->count[0] += len << 3) < (len << 3)) context->count[1]++;

    context->count[1] += (len >> 29);

    if ((j + len) > 63) 
  {
        memcpy(&context->buffer[j], data, (i = 64-j));
        SHA1_Transform(context->state, context->buffer);

        for ( ; i + 63 < len; i += 64) 
    {
            SHA1_Transform(context->state, data + i);
        }

        j = 0;
    }
    else i = 0;
    memcpy(&context->buffer[j], &data[i], len - i);
}

struct work_todo_argument
{
  SHA1_CTX *v1;
  char *v2;
  int v3;
};

static void *
work_todo (void *v)
{
  struct work_todo_argument *p = v;
  SHA1_Update (p->v1, (uint8_t *)p->v2, p->v3);
  return NULL;
}

void *
work_thread (void *arg)
{
  long i;
  unsigned long pid = (unsigned long) arg;
  unsigned long long start, end;
  struct work_todo_argument work_todo_arg;
  struct numa_spinlock_queue_info queue_info;
  
  if (init_numa_spinlock_queue_info (&queue_info))
    {
      printf ("init_numa_spinlock_queue_info failure: %m\n");
      exit (1);
    }
  char buf[HASHBUF];
  SHA1_CTX ctx;

  memset (buf, 0x1, HASHBUF);
  SHA1_Init (&ctx);

  work_todo_arg.v1 = &ctx;
  work_todo_arg.v2 = buf;
  work_todo_arg.v3 = HASHBUF;
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
    }
  end = __builtin_ia32_rdtscp (&aux);
  gcount[pid].total = end - start;

  return NULL;
}

void
test_threads (int numthreads)
{
  queue = init_numa_spinlock_queue ();
  memory_barrier ();

  pthread_t thr[numthreads];
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

  for (i = 0; i < numthreads; i++)
    pthread_join (thr[i], NULL);
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

  memset (gcount, 0, sizeof(gcount[0]) * numthreads);

  test_threads (numthreads);

  for (i = 0; i < numthreads; i++)
      total += gcount[i].total;

  struct count cost = { total };
  return cost;
}

int
main (void)
{
  int numthreads = sysconf (_SC_NPROCESSORS_ONLN);
  if (numthreads < 8)
    return 1;

  ops = &cmpxchg_ops;

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
