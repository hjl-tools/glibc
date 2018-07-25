/* This file is part of the GNU C Library.
   Copyright (C) 2018 Free Software Foundation, Inc.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <http://www.gnu.org/licenses/>.  */

#include_next <cpu-features.h>

#ifndef _include_cpu_features_h
#define _include_cpu_features_h

/* XCR0 Feature flags.  */
#define bit_XMM_state		(1u << 1)
#define bit_YMM_state		(1u << 2)
#define bit_Opmask_state	(1u << 5)
#define bit_ZMM0_15_state	(1u << 6)
#define bit_ZMM16_31_state	(1u << 7)

struct cpu_features
{
  enum cpu_features_kind kind;
  int max_cpuid;
  struct cpuid_registers cpuid[COMMON_CPUID_INDEX_MAX];
  unsigned int family;
  unsigned int model;
  /* The state size for XSAVEC or XSAVE.  The type must be unsigned long
     int so that we use

	sub xsave_state_size_offset(%rip) %RSP_LP

     in _dl_runtime_resolve.  */
  unsigned long int xsave_state_size;
  /* The full state size for XSAVE when XSAVEC is disabled by

     GLIBC_TUNABLES=glibc.tune.hwcaps=-XSAVEC_Usable
   */
  unsigned int xsave_state_full_size;
  unsigned int feature[FEATURE_INDEX_MAX];
  /* Data cache size for use in memory and string routines, typically
     L1 size.  */
  unsigned long int data_cache_size;
  /* Shared cache size for use in memory and string routines, typically
     L2 or L3 size.  */
  unsigned long int shared_cache_size;
  /* Threshold to use non temporal store.  */
  unsigned long int non_temporal_threshold;
};

/* Used from outside of glibc to get access to the CPU features
   structure.  */
extern const struct cpu_features *__get_cpu_features (void)
     __attribute__ ((const));

/* Only used directly in cpu-features.c.  */
# define CPU_FEATURES_CPU_P(ptr, name) \
  ((ptr->cpuid[index_cpu_##name].reg_##name & (bit_cpu_##name)) != 0)
# define CPU_FEATURES_ARCH_P(ptr, name) \
  ((ptr->feature[index_arch_##name] & (bit_arch_##name)) != 0)

# if defined (_LIBC) && !IS_IN (nonlib)
/* Unused for x86.  */
#  define INIT_ARCH()
#  define __get_cpu_features()	(&GLRO(dl_x86_cpu_features))
#  define __get_cpuid_registers(i) (&(GLRO(dl_x86_cpu_features).cpuid[i]))
#  define __get_arch_feature(i)	GLRO(dl_x86_cpu_features).feature[i]
# endif

#ifdef __x86_64__
# define HAS_CPUID 1
#elif defined __i586__ || defined __pentium__
# define HAS_CPUID 1
# define HAS_I586 1
# define HAS_I686 HAS_ARCH_FEATURE (I686)
#elif (defined __i686__ || defined __pentiumpro__		\
       || defined __pentium4__ || defined __nocona__		\
       || defined __atom__ || defined __core2__			\
       || defined __corei7__ || defined __corei7_avx__		\
       || defined __core_avx2__	|| defined __nehalem__		\
       || defined __sandybridge__ || defined __haswell__	\
       || defined __knl__ || defined __bonnell__		\
       || defined __silvermont__				\
       || defined __k6__ || defined __k8__			\
       || defined __athlon__ || defined __amdfam10__		\
       || defined __bdver1__ || defined __bdver2__		\
       || defined __bdver3__ || defined __bdver4__		\
       || defined __btver1__ || defined __btver2__)
# define HAS_CPUID 1
# define HAS_I586 1
# define HAS_I686 1
#else
# define HAS_CPUID 0
# define HAS_I586 HAS_ARCH_FEATURE (I586)
# define HAS_I686 HAS_ARCH_FEATURE (I686)
#endif

#endif  /* _include_cpu_features_h */
