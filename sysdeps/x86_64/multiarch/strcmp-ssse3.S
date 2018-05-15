#if IS_IN (libc) || IS_IN (libcpu_rt_c)
# define USE_SSSE3 1
# define STRCMP __strcmp_ssse3
# include "../strcmp.S"
#endif
