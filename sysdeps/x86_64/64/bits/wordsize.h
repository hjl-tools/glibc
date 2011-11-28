/* Determine the wordsize from the preprocessor defines.  */

#if defined __LP64__
# define __WORDSIZE	64
#else
# define __WORDSIZE	32
#endif
