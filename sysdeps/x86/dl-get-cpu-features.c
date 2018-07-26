/* This file is part of the GNU C Library.
   Copyright (C) 2015-2018 Free Software Foundation, Inc.

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


#include <ldsodefs.h>

#undef __get_cpu_features
#undef x86_get_cpuid_registers
#undef x86_get_arch_feature

const struct cpu_features *
__get_cpu_features (void)
{
  return &GLRO(dl_x86_cpu_features);
}

const struct cpuid_registers *
x86_get_cpuid_registers (unsigned int i)
{
  const static struct cpuid_registers zero_cpuid_registers = { 0 };
  if (i >= COMMON_CPUID_INDEX_MAX)
    return &zero_cpuid_registers;
  return &GLRO(dl_x86_cpu_features).cpuid[i];
}

unsigned int
x86_get_arch_feature (unsigned int i)
{
  if (i >= COMMON_CPUID_INDEX_MAX)
    return 0;
  return GLRO(dl_x86_cpu_features).feature[i];
}
