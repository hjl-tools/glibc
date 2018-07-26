/* This file is part of the GNU C Library.
   Copyright (C) 2008-2018 Free Software Foundation, Inc.

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

#ifndef cpu_features_h
#define cpu_features_h

#include <sys/platform/x86.h>

/* FEATURE_INDEX_2.  */
#define bit_arch_I586				(1u << 0)
#define bit_arch_I686				(1u << 1)
#define bit_arch_Fast_Rep_String		(1u << 2)
#define bit_arch_Fast_Copy_Backward		(1u << 3)
#define bit_arch_Fast_Unaligned_Load		(1u << 4)
#define bit_arch_Fast_Unaligned_Copy		(1u << 5)
#define bit_arch_Slow_BSF			(1u << 6)
#define bit_arch_Slow_SSE4_2			(1u << 7)
#define bit_arch_AVX_Fast_Unaligned_Load	(1u << 8)
#define bit_arch_Prefer_MAP_32BIT_EXEC		(1u << 9)
#define bit_arch_Prefer_PMINUB_for_stringop	(1u << 10)
#define bit_arch_Prefer_No_VZEROUPPER		(1u << 11)
#define bit_arch_Prefer_ERMS			(1u << 12)
#define bit_arch_Prefer_FSRM			(1u << 13)
#define bit_arch_Prefer_No_AVX512		(1u << 14)
#define bit_arch_MathVec_Prefer_No_AVX512	(1u << 15)

#define index_arch_Fast_Rep_String		FEATURE_INDEX_2
#define index_arch_Fast_Copy_Backward		FEATURE_INDEX_2
#define index_arch_Slow_BSF			FEATURE_INDEX_2
#define index_arch_Fast_Unaligned_Load		FEATURE_INDEX_2
#define index_arch_Prefer_PMINUB_for_stringop 	FEATURE_INDEX_2
#define index_arch_Fast_Unaligned_Copy		FEATURE_INDEX_2
#define index_arch_I586				FEATURE_INDEX_2
#define index_arch_I686				FEATURE_INDEX_2
#define index_arch_Slow_SSE4_2			FEATURE_INDEX_2
#define index_arch_AVX_Fast_Unaligned_Load	FEATURE_INDEX_2
#define index_arch_Prefer_MAP_32BIT_EXEC	FEATURE_INDEX_2
#define index_arch_Prefer_No_VZEROUPPER		FEATURE_INDEX_2
#define index_arch_Prefer_ERMS			FEATURE_INDEX_2
#define index_arch_Prefer_No_AVX512		FEATURE_INDEX_2
#define index_arch_MathVec_Prefer_No_AVX512	FEATURE_INDEX_2
#define index_arch_Prefer_FSRM			FEATURE_INDEX_2

/* XCR0 Feature flags.  */
#define bit_XMM_state		(1u << 1)
#define bit_YMM_state		(1u << 2)
#define bit_Opmask_state	(1u << 5)
#define bit_ZMM0_15_state	(1u << 6)
#define bit_ZMM16_31_state	(1u << 7)

enum cpu_features_kind
  {
    arch_kind_unknown = 0,
    arch_kind_intel,
    arch_kind_amd,
    arch_kind_other
  };

/* Time Stamp Counter and Nominal Core Crystal Clock Information.  */
struct tsc_nccc_info
{
  /* The denominator of the TSC/core crystal clock ratio.  */
  unsigned int denominator;
  /* The numerator of the TSC/core crystal clock ratio.  */
  unsigned int nominator;
  /* The nominal frequency of the core crystal clock in Hz.  */
  unsigned int frequency;
};

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

     GLIBC_TUNABLES=glibc.cpu.hwcaps=-XSAVEC_Usable
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
  /* Time Stamp Counter and Nominal Core Crystal Clock Information.  */
  struct tsc_nccc_info tsc_nccc_data;
};

/* Used from outside of glibc to get access to the CPU features
   structure.  */
extern const struct cpu_features *__get_cpu_features (void)
     __attribute__ ((const));

# if defined (_LIBC) && !IS_IN (nonlib)
/* Unused for x86.  */
#  define INIT_ARCH()
#  define __get_cpu_features()	(&GLRO(dl_x86_cpu_features))
#  define x86_get_cpuid_registers(i) \
       (&(GLRO(dl_x86_cpu_features).cpuid[i]))
# endif


/* Only used directly in cpu-features.c.  */
# define CPU_FEATURES_CPU_P(ptr, name) \
  ((ptr->cpuid[index_cpu_##name].reg_##name & (bit_cpu_##name)) != 0)
# define CPU_FEATURES_ARCH_P(ptr, name) \
  ((ptr->feature[index_arch_##name] & (bit_arch_##name)) != 0)

/* HAS_CPU_FEATURE evaluates to true if CPU supports the feature.  */
#define HAS_CPU_FEATURE(name) \
  CPU_FEATURES_CPU_P (__get_cpu_features (), name)
/* HAS_ARCH_FEATURE evaluates to true if we may use the feature at
   runtime.  */
# define HAS_ARCH_FEATURE(name) \
  CPU_FEATURES_ARCH_P (__get_cpu_features (), name)

#ifdef __x86_64__
# define HAS_CPUID 1
#elif (defined __i586__ || defined __pentium__	\
       || defined __geode__ || defined __k6__)
# define HAS_CPUID 1
# define HAS_I586 1
# define HAS_I686 HAS_ARCH_FEATURE (I686)
#elif defined __i486__
# define HAS_CPUID 0
# define HAS_I586 HAS_ARCH_FEATURE (I586)
# define HAS_I686 HAS_ARCH_FEATURE (I686)
#else
# define HAS_CPUID 1
# define HAS_I586 1
# define HAS_I686 1
#endif

#endif  /* cpu_features_h */
