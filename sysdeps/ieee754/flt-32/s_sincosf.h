/* Used by sinf, cosf and sincosf functions.
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

#include <stdint.h>
#include <math.h>
#include "math_config.h"

typedef double v2df_t __attribute__ ((vector_size (2 * sizeof (double))));

#include <v2df_to_sf.h>

/* 2PI * 2^-64.  */
static const double pi63 = 0x1.921FB54442D18p-62;
/* PI / 4.  */
static const double pio4 = 0x1.921FB54442D18p-1;

/* The constants and polynomials for sine and cosine.  */
typedef struct
{
  double sign[4];		/* Sign of sine in quadrants 0..3.  */
  double hpi_inv;		/* 2 / PI ( * 2^24 if !TOINT_INTRINSICS).  */
  double hpi;			/* PI / 2.  */
  /* Cosine polynomial: c0, c1, c2, c3, c4.
     Sine polynomial: s1, s2, s3.  */
  double c0, c1;
  v2df_t s1c2, s2c3, s3c4;
} sincos_t;

/* Polynomial data (the cosine polynomial is negated in the 2nd entry).  */
extern const sincos_t __sincosf_table[2] attribute_hidden;

/* Table with 4/PI to 192 bit precision.  */
extern const uint32_t __inv_pio4[] attribute_hidden;

/* Top 12 bits of the float representation with the sign bit cleared.  */
static inline uint32_t
abstop12 (float x)
{
  return (asuint (x) >> 20) & 0x7ff;
}

/* Compute the sine and cosine of inputs X and X2 (X squared), using the
   polynomial P and store the results in SINP and COSP.  N is the quadrant,
   if odd the cosine and sine polynomials are swapped.  */
static inline void
sincosf_poly (double x, double x2, const sincos_t *p, int n, float *sinp,
	      float *cosp)
{
  v2df_t vx2x2 = { x2, x2 };
  v2df_t vxx2 = { x, x2 };
  v2df_t vx3x4, vs1c2;

  vx3x4 = vx2x2 * vxx2;
  vs1c2 = p->s2c3 + vx2x2 * p->s3c4;

  /* Swap sin/cos result based on quadrant.  */
  if (n & 1)
    {
      float *tmp = cosp;
      cosp = sinp;
      sinp = tmp;
    }

  double c1 = p->c0 + x2 * p->c1;
  v2df_t vxc1 = { x, c1 };
  v2df_t vx5x6 = vx3x4 * vx2x2;

  v2df_t vsincos = vxc1 + vx3x4 * p->s1c2;
  vsincos = vsincos + vx5x6 * vs1c2;
  v2df_to_sf (vsincos, sinp, cosp);
}

/* Return the sine of inputs X and X2 (X squared) using the polynomial P.
   N is the quadrant, and if odd the cosine polynomial is used.  */
static inline float
sinf_poly (double x, double x2, const sincos_t *p, int n)
{
  double x3, x4, x6, x7, s, c, c1, c2, s1;

  if ((n & 1) == 0)
    {
      x3 = x * x2;
      s1 = p->s2c3[0] + x2 * p->s3c4[0];

      x7 = x3 * x2;
      s = x + x3 * p->s1c2[0];

      return s + x7 * s1;
    }
  else
    {
      x4 = x2 * x2;
      c2 = p->s2c3[1] + x2 * p->s3c4[1];
      c1 = p->c0 + x2 * p->c1;

      x6 = x4 * x2;
      c = c1 + x4 * p->s1c2[1];

      return c + x6 * c2;
    }
}

/* Fast range reduction using single multiply-subtract.  Return the modulo of
   X as a value between -PI/4 and PI/4 and store the quadrant in NP.
   The values for PI/2 and 2/PI are accessed via P.  Since PI/2 as a double
   is accurate to 55 bits and the worst-case cancellation happens at 6 * PI/4,
   the result is accurate for |X| <= 120.0.  */
static inline double
reduce_fast (double x, const sincos_t *p, int *np)
{
  double r;
#if TOINT_INTRINSICS
  /* Use fast round and lround instructions when available.  */
  r = x * p->hpi_inv;
  *np = converttoint (r);
  return x - roundtoint (r) * p->hpi;
#else
  /* Use scaled float to int conversion with explicit rounding.
     hpi_inv is prescaled by 2^24 so the quadrant ends up in bits 24..31.
     This avoids inaccuracies introduced by truncating negative values.  */
  r = x * p->hpi_inv;
  int n = ((int32_t)r + 0x800000) >> 24;
  *np = n;
  return x - n * p->hpi;
#endif
}

/* Reduce the range of XI to a multiple of PI/2 using fast integer arithmetic.
   XI is a reinterpreted float and must be >= 2.0f (the sign bit is ignored).
   Return the modulo between -PI/4 and PI/4 and store the quadrant in NP.
   Reduction uses a table of 4/PI with 192 bits of precision.  A 32x96->128 bit
   multiply computes the exact 2.62-bit fixed-point modulo.  Since the result
   can have at most 29 leading zeros after the binary point, the double
   precision result is accurate to 33 bits.  */
static inline double
reduce_large (uint32_t xi, int *np)
{
  const uint32_t *arr = &__inv_pio4[(xi >> 26) & 15];
  int shift = (xi >> 23) & 7;
  uint64_t n, res0, res1, res2;

  xi = (xi & 0xffffff) | 0x800000;
  xi <<= shift;

  res0 = xi * arr[0];
  res1 = (uint64_t)xi * arr[4];
  res2 = (uint64_t)xi * arr[8];
  res0 = (res2 >> 32) | (res0 << 32);
  res0 += res1;

  n = (res0 + (1ULL << 61)) >> 62;
  res0 -= n << 62;
  double x = (int64_t)res0;
  *np = n;
  return x * pi63;
}
