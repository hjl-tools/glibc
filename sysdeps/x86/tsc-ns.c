/* Conversion functions between TSCs and nanoseconds.
   Copyright (C) 2018 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

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

static struct tsc_nccc_info tsc_nccc_data;

static void
__attribute__((constructor))
init_tsc_nccc_data (void)
{
  const struct cpu_features* cpu_features = __get_cpu_features ();
  if (CPU_FEATURES_ARCH_P (cpu_features, TSC_To_NS_Usable))
    tsc_nccc_data = cpu_features->tsc_nccc_data;
}

unsigned long long
__tsc_to_ns (unsigned long long tsc)
{
  if (__glibc_unlikely (tsc_nccc_data.frequency == 0))
    return 0;

  /* Use double to avoid integer overflow.  */
  double tmp = tsc;
  tmp *= tsc_nccc_data.denominator * 1000000;
  tmp /= tsc_nccc_data.frequency;
  unsigned long long ns = tmp;
  /* Round to the closest integer.  */
  ns += tsc_nccc_data.nominator / 2;
  return ns / tsc_nccc_data.nominator;

}

unsigned long long
__ns_to_tsc (unsigned long long ns)
{
  if (__glibc_unlikely (tsc_nccc_data.frequency == 0))
    return 0;

  /* Use double to avoid integer overflow.  */
  double tmp = ns;
  tmp *= tsc_nccc_data.frequency;
  tmp *= tsc_nccc_data.nominator;
  tmp /= tsc_nccc_data.denominator;
  unsigned long long tsc = tmp;
  /* Round to the closest integer.  */
  ns += 1000000 / 2;
  return tsc / 1000000;
}
