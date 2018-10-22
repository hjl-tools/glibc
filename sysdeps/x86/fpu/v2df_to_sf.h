/* Convert V2DF to SF.  x86 version.
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

#ifdef __SSE2_MATH__
typedef float v4sf_t __attribute__ ((vector_size (4 * sizeof (float))));

static inline void
v2df_to_sf (v2df_t v2df, float *f0p, float *f1p)
{
  v4sf_t v4sf = __builtin_ia32_cvtpd2ps (v2df);
  *f0p = v4sf[0];
  *f1p = v4sf[1];
}
#else
# include <sysdeps/ieee754/flt-32/v2df_to_sf.h>
#endif
