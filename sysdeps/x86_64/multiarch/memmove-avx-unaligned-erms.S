#if IS_IN (libc) || IS_IN (libcpu_rt_c)
# define VEC_SIZE	32
# define VEC(i)		ymm##i
# define VMOVNT		vmovntdq
# define VMOVU		vmovdqu
# define VMOVA		vmovdqa

# define SECTION(p)		p##.avx
# define MEMMOVE_SYMBOL(p,s)	p##_avx_##s

# include "memmove-vec-unaligned-erms.S"
#endif
