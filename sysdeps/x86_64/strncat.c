#if IS_IN (libcpu_rt_c)
# include <string.h>
extern __typeof (strnlen) __strnlen attribute_hidden;
# ifndef STRNCAT
#  define STRNCAT strncat
# endif
#endif

#include <string/strncat.c>
