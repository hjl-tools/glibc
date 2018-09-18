/* strcpy with AVX2
   Copyright (C) 2011-2018 Free Software Foundation, Inc.
   Contributed by Intel Corporation.
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

#if IS_IN (libc)

# ifndef USE_AS_STRCAT
#  include <sysdep.h>

#  ifndef STRCPY
#   define STRCPY  __strcpy_avx2
#  endif

# endif

# define JMPTBL(I, B)	I - B
# define BRANCH_TO_JMPTBL_ENTRY(TABLE, INDEX, SCALE)             \
	lea	TABLE(%rip), %r11;                              \
	movslq	(%r11, INDEX, SCALE), %rcx;                     \
	lea	(%r11, %rcx), %rcx;                             \
	_CET_NOTRACK jmp *%rcx

/* Number of bytes in a vector register */
# ifndef VEC_SIZE
#  define VEC_SIZE	32
# endif

# ifndef VZEROUPPER
#  define VZEROUPPER	vzeroupper
# endif

#define xmmZ	xmm8
#define ymmZ	ymm8

# ifndef USE_AS_STRCAT

.text
ENTRY (STRCPY)
#  ifdef USE_AS_STRNCPY
	mov	%rdx, %r8
	test	%r8, %r8
	jz	L(ExitZero)
#  endif
	mov	%rsi, %rcx
#  ifndef USE_AS_STPCPY
	mov	%rdi, %rax      /* save result */
#  endif

# endif

	vpxor	%xmmZ, %xmmZ, %xmmZ

	and	$((VEC_SIZE * 4) - 1), %rcx
	cmp	$(VEC_SIZE * 2), %rcx
	jbe	L(SourceStringAlignmentLessTwoVecSize)

	and	$-VEC_SIZE, %rsi
	and	$(VEC_SIZE - 1), %rcx
	vpxor	%xmm0, %xmm0, %xmm0
	vpxor	%xmm1, %xmm1, %xmm1

	vpcmpeqb (%rsi), %ymmZ, %ymm1
	vpmovmskb %ymm1, %rdx
	shr	%cl, %rdx

# ifdef USE_AS_STRNCPY
#  if defined USE_AS_STPCPY || defined USE_AS_STRCAT
	mov	$VEC_SIZE, %r10
	sub	%rcx, %r10
	cmp	%r10, %r8
#  else
	mov	$(VEC_SIZE + 1), %r10
	sub	%rcx, %r10
	cmp	%r10, %r8
#  endif
	jbe	L(CopyVecSizeTailCase2OrCase3)
# endif
	test	%rdx, %rdx
	jnz	L(CopyVecSizeTail)

	vpcmpeqb VEC_SIZE(%rsi), %ymmZ, %ymm0
	vpmovmskb %ymm0, %rdx

# ifdef USE_AS_STRNCPY
	add	$VEC_SIZE, %r10
	cmp	%r10, %r8
	jbe	L(CopyTwoVecSizeCase2OrCase3)
# endif
	test	%rdx, %rdx
	jnz	L(CopyTwoVecSize)

	vmovdqu (%rsi, %rcx), %ymm1   /* copy VEC_SIZE bytes */
	vmovdqu %ymm1, (%rdi)

/* If source address alignment != destination address alignment */
	.p2align 4
L(UnalignVecSizeBoth):
	sub	%rcx, %rdi
# ifdef USE_AS_STRNCPY
	add	%rcx, %r8
	sbb	%rcx, %rcx
	or	%rcx, %r8
# endif
	mov	$VEC_SIZE, %rcx
	vmovdqa (%rsi, %rcx), %ymm1
	vmovdqa VEC_SIZE(%rsi, %rcx), %ymm2
	vmovdqu %ymm1, (%rdi, %rcx)
	vpcmpeqb %ymm2, %ymmZ, %ymm0
	vpmovmskb %ymm0, %rdx
	add	$VEC_SIZE, %rcx
# ifdef USE_AS_STRNCPY
	sub	$(VEC_SIZE * 3), %r8
	jbe	L(CopyVecSizeCase2OrCase3)
# endif
	test	%rdx, %rdx
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec2)
# else
	jnz	L(CopyVecSize)
# endif

	vmovdqa VEC_SIZE(%rsi, %rcx), %ymm3
	vmovdqu %ymm2, (%rdi, %rcx)
	vpcmpeqb %ymm3, %ymmZ, %ymm0
	vpmovmskb %ymm0, %rdx
	add	$VEC_SIZE, %rcx
# ifdef USE_AS_STRNCPY
	sub	$VEC_SIZE, %r8
	jbe	L(CopyVecSizeCase2OrCase3)
# endif
	test	%rdx, %rdx
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec3)
# else
	jnz	L(CopyVecSize)
# endif

	vmovdqa VEC_SIZE(%rsi, %rcx), %ymm4
	vmovdqu %ymm3, (%rdi, %rcx)
	vpcmpeqb %ymm4, %ymmZ, %ymm0
	vpmovmskb %ymm0, %rdx
	add	$VEC_SIZE, %rcx
# ifdef USE_AS_STRNCPY
	sub	$VEC_SIZE, %r8
	jbe	L(CopyVecSizeCase2OrCase3)
# endif
	test	%rdx, %rdx
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec4)
# else
	jnz	L(CopyVecSize)
# endif

	vmovdqa VEC_SIZE(%rsi, %rcx), %ymm1
	vmovdqu %ymm4, (%rdi, %rcx)
	vpcmpeqb %ymm1, %ymmZ, %ymm0
	vpmovmskb %ymm0, %rdx
	add	$VEC_SIZE, %rcx
# ifdef USE_AS_STRNCPY
	sub	$VEC_SIZE, %r8
	jbe	L(CopyVecSizeCase2OrCase3)
# endif
	test	%rdx, %rdx
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec1)
# else
	jnz	L(CopyVecSize)
# endif

	vmovdqa VEC_SIZE(%rsi, %rcx), %ymm2
	vmovdqu %ymm1, (%rdi, %rcx)
	vpcmpeqb %ymm2, %ymmZ, %ymm0
	vpmovmskb %ymm0, %rdx
	add	$VEC_SIZE, %rcx
# ifdef USE_AS_STRNCPY
	sub	$VEC_SIZE, %r8
	jbe	L(CopyVecSizeCase2OrCase3)
# endif
	test	%rdx, %rdx
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec2)
# else
	jnz	L(CopyVecSize)
# endif

	vmovdqa VEC_SIZE(%rsi, %rcx), %ymm3
	vmovdqu %ymm2, (%rdi, %rcx)
	vpcmpeqb %ymm3, %ymmZ, %ymm0
	vpmovmskb %ymm0, %rdx
	add	$VEC_SIZE, %rcx
# ifdef USE_AS_STRNCPY
	sub	$VEC_SIZE, %r8
	jbe	L(CopyVecSizeCase2OrCase3)
# endif
	test	%rdx, %rdx
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec3)
# else
	jnz	L(CopyVecSize)
# endif

	vmovdqu %ymm3, (%rdi, %rcx)
	mov	%rsi, %rdx
	lea	VEC_SIZE(%rsi, %rcx), %rsi
	and	$-(VEC_SIZE * 4), %rsi
	sub	%rsi, %rdx
	sub	%rdx, %rdi
# ifdef USE_AS_STRNCPY
	lea	(VEC_SIZE * 8)(%r8, %rdx), %r8
# endif
L(UnalignedFourVecSizeLoop):
	vmovdqa (%rsi), %ymm4
	vmovdqa VEC_SIZE(%rsi), %ymm5
	vmovdqa (VEC_SIZE * 2)(%rsi), %ymm6
	vmovdqa (VEC_SIZE * 3)(%rsi), %ymm7
	vpminub %ymm5, %ymm4, %ymm2
	vpminub %ymm7, %ymm6, %ymm3
	vpminub %ymm2, %ymm3, %ymm3
	vpcmpeqb %ymm0, %ymm3, %ymm3
	vpmovmskb %ymm3, %rdx
# ifdef USE_AS_STRNCPY
	sub	$(VEC_SIZE * 4), %r8
	jbe	L(UnalignedLeaveCase2OrCase3)
# endif
	test	%rdx, %rdx
	jnz	L(UnalignedFourVecSizeLeave)

L(UnalignedFourVecSizeLoop_start):
	add	$(VEC_SIZE * 4), %rdi
	add	$(VEC_SIZE * 4), %rsi
	vmovdqu %ymm4, -(VEC_SIZE * 4)(%rdi)
	vmovdqa (%rsi), %ymm4
	vmovdqu %ymm5, -(VEC_SIZE * 3)(%rdi)
	vmovdqa VEC_SIZE(%rsi), %ymm5
	vpminub %ymm5, %ymm4, %ymm2
	vmovdqu %ymm6, -(VEC_SIZE * 2)(%rdi)
	vmovdqa (VEC_SIZE * 2)(%rsi), %ymm6
	vmovdqu %ymm7, -VEC_SIZE(%rdi)
	vmovdqa (VEC_SIZE * 3)(%rsi), %ymm7
	vpminub %ymm7, %ymm6, %ymm3
	vpminub %ymm2, %ymm3, %ymm3
	vpcmpeqb %ymm0, %ymm3, %ymm3
	vpmovmskb %ymm3, %rdx
# ifdef USE_AS_STRNCPY
	sub	$(VEC_SIZE * 4), %r8
	jbe	L(UnalignedLeaveCase2OrCase3)
# endif
	test	%rdx, %rdx
	jz	L(UnalignedFourVecSizeLoop_start)

L(UnalignedFourVecSizeLeave):
	vpcmpeqb %ymm4, %ymm0, %ymm0
	vpmovmskb %ymm0, %rdx
	test	%rdx, %rdx
	jnz	L(CopyVecSizeUnaligned_0)

	vpcmpeqb %ymm5, %ymmZ, %ymm1
	vpmovmskb %ymm1, %rcx
	test	%rcx, %rcx
	jnz	L(CopyVecSizeUnaligned_16)

	vpcmpeqb %ymm6, %ymm0, %ymm0
	vpmovmskb %ymm0, %rdx
	test	%rdx, %rdx
	jnz	L(CopyVecSizeUnaligned_32)

	vpcmpeqb %ymm7, %ymmZ, %ymm1
	vpmovmskb %ymm1, %rcx
	bsf	%rcx, %rdx
	vmovdqu %ymm4, (%rdi)
	vmovdqu %ymm5, VEC_SIZE(%rdi)
	vmovdqu %ymm6, (VEC_SIZE * 2)(%rdi)
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
# ifdef USE_AS_STPCPY
	lea	(VEC_SIZE * 3)(%rdi, %rdx), %rax
# endif
	vmovdqu %ymm7, (VEC_SIZE * 3)(%rdi)
	add	$(VEC_SIZE - 1), %r8
	sub	%rdx, %r8
	lea	((VEC_SIZE * 3) + 1)(%rdi, %rdx), %rdi
	jmp	L(StrncpyFillTailWithZero)
# else
	add	$(VEC_SIZE * 3), %rsi
	add	$(VEC_SIZE * 3), %rdi
	BRANCH_TO_JMPTBL_ENTRY (L(ExitTable), %rdx, 4)
# endif

/* If source address alignment == destination address alignment */

L(SourceStringAlignmentLessTwoVecSize):
	vmovdqu (%rsi), %ymm1
	vmovdqu VEC_SIZE(%rsi), %ymm2
	vpcmpeqb %ymm1, %ymmZ, %ymm0
	vpmovmskb %ymm0, %rdx

# ifdef USE_AS_STRNCPY
#  if defined USE_AS_STPCPY || defined USE_AS_STRCAT
	cmp	$VEC_SIZE, %r8
#  else
	cmp	$(VEC_SIZE + 1), %r8
#  endif
	jbe	L(CopyVecSizeTail1Case2OrCase3)
# endif
	test	%rdx, %rdx
	jnz	L(CopyVecSizeTail1)

	vpcmpeqb %ymm2, %ymmZ, %ymm0
	vmovdqu %ymm1, (%rdi)
	vpmovmskb %ymm0, %rdx

# ifdef USE_AS_STRNCPY
#  if defined USE_AS_STPCPY || defined USE_AS_STRCAT
	cmp	$(VEC_SIZE * 2), %r8
#  else
	cmp	$((VEC_SIZE * 2) + 1), %r8
#  endif
	jbe	L(CopyTwoVecSize1Case2OrCase3)
# endif
	test	%rdx, %rdx
	jnz	L(CopyTwoVecSize1)

	and	$-VEC_SIZE, %rsi
	and	$(VEC_SIZE - 1), %rcx
	jmp	L(UnalignVecSizeBoth)

/*------End of main part with loops---------------------*/

/* Case1 */

# if (!defined USE_AS_STRNCPY) || (defined USE_AS_STRCAT)
	.p2align 4
L(CopyVecSize):
	add	%rcx, %rdi
	add	%rcx, %rsi
	bsf	%rdx, %rdx
	BRANCH_TO_JMPTBL_ENTRY (L(ExitTable), %rdx, 4)
# endif
	.p2align 4
L(CopyVecSizeTail):
	add	%rcx, %rsi
	bsf	%rdx, %rdx
	BRANCH_TO_JMPTBL_ENTRY (L(ExitTable), %rdx, 4)

	.p2align 4
L(CopyTwoVecSize1):
	add	$VEC_SIZE, %rsi
	add	$VEC_SIZE, %rdi
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$VEC_SIZE, %r8
# endif
L(CopyVecSizeTail1):
	bsf	%rdx, %rdx
	BRANCH_TO_JMPTBL_ENTRY (L(ExitTable), %rdx, 4)

	.p2align 4
L(CopyTwoVecSize):
	bsf	%rdx, %rdx
	add	%rcx, %rsi
	add	$VEC_SIZE, %rdx
	sub	%rcx, %rdx
	BRANCH_TO_JMPTBL_ENTRY (L(ExitTable), %rdx, 4)

	.p2align 4
L(CopyVecSizeUnaligned_0):
	bsf	%rdx, %rdx
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
# ifdef USE_AS_STPCPY
	lea	(%rdi, %rdx), %rax
# endif
	vmovdqu %ymm4, (%rdi)
	add	$((VEC_SIZE * 4) - 1), %r8
	sub	%rdx, %r8
	lea	1(%rdi, %rdx), %rdi
	jmp	L(StrncpyFillTailWithZero)
# else
	BRANCH_TO_JMPTBL_ENTRY (L(ExitTable), %rdx, 4)
# endif

	.p2align 4
L(CopyVecSizeUnaligned_16):
	bsf	%rcx, %rdx
	vmovdqu %ymm4, (%rdi)
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
# ifdef USE_AS_STPCPY
	lea	VEC_SIZE(%rdi, %rdx), %rax
# endif
	vmovdqu %ymm5, VEC_SIZE(%rdi)
	add	$((VEC_SIZE * 3) - 1), %r8
	sub	%rdx, %r8
	lea	(VEC_SIZE + 1)(%rdi, %rdx), %rdi
	jmp	L(StrncpyFillTailWithZero)
# else
	add	$VEC_SIZE, %rsi
	add	$VEC_SIZE, %rdi
	BRANCH_TO_JMPTBL_ENTRY (L(ExitTable), %rdx, 4)
# endif

	.p2align 4
L(CopyVecSizeUnaligned_32):
	bsf	%rdx, %rdx
	vmovdqu %ymm4, (%rdi)
	vmovdqu %ymm5, VEC_SIZE(%rdi)
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
# ifdef USE_AS_STPCPY
	lea	(VEC_SIZE * 2)(%rdi, %rdx), %rax
# endif
	vmovdqu %ymm6, (VEC_SIZE * 2)(%rdi)
	add	$((VEC_SIZE * 2) - 1), %r8
	sub	%rdx, %r8
	lea	((VEC_SIZE * 2) + 1)(%rdi, %rdx), %rdi
	jmp	L(StrncpyFillTailWithZero)
# else
	add	$(VEC_SIZE * 2), %rsi
	add	$(VEC_SIZE * 2), %rdi
	BRANCH_TO_JMPTBL_ENTRY (L(ExitTable), %rdx, 4)
# endif

# ifdef USE_AS_STRNCPY
#  ifndef USE_AS_STRCAT
	.p2align 4
L(CopyVecSizeUnalignedVec6):
	vmovdqu %ymm6, (%rdi, %rcx)
	jmp	L(CopyVecSizeVecExit)

	.p2align 4
L(CopyVecSizeUnalignedVec5):
	vmovdqu %ymm5, (%rdi, %rcx)
	jmp	L(CopyVecSizeVecExit)

	.p2align 4
L(CopyVecSizeUnalignedVec4):
	vmovdqu %ymm4, (%rdi, %rcx)
	jmp	L(CopyVecSizeVecExit)

	.p2align 4
L(CopyVecSizeUnalignedVec3):
	vmovdqu %ymm3, (%rdi, %rcx)
	jmp	L(CopyVecSizeVecExit)

	.p2align 4
L(CopyVecSizeUnalignedVec1):
	vmovdqu %ymm1, (%rdi, %rcx)
	jmp	L(CopyVecSizeVecExit)
#  endif

	.p2align 4
L(CopyVecSizeExit):
	BRANCH_TO_JMPTBL_ENTRY (L(ExitTable), %rdx, 4)

/* Case2 */

	.p2align 4
L(CopyVecSizeCase2):
	add	$VEC_SIZE, %r8
	add	%rcx, %rdi
	add	%rcx, %rsi
	bsf	%rdx, %rdx
	cmp	%r8, %rdx
	jb	L(CopyVecSizeExit)
	BRANCH_TO_JMPTBL_ENTRY (L(ExitStrncpyTable), %r8, 4)

	.p2align 4
L(CopyTwoVecSizeCase2):
	add	%rcx, %rsi
	bsf	%rdx, %rdx
	add	$VEC_SIZE, %rdx
	sub	%rcx, %rdx
	cmp	%r8, %rdx
	jb	L(CopyVecSizeExit)
	BRANCH_TO_JMPTBL_ENTRY (L(ExitStrncpyTable), %r8, 4)

L(CopyVecSizeTailCase2):
	add	%rcx, %rsi
	bsf	%rdx, %rdx
	cmp	%r8, %rdx
	jb	L(CopyVecSizeExit)
	BRANCH_TO_JMPTBL_ENTRY (L(ExitStrncpyTable), %r8, 4)

L(CopyVecSizeTail1Case2):
	bsf	%rdx, %rdx
	cmp	%r8, %rdx
	jb	L(CopyVecSizeExit)
	BRANCH_TO_JMPTBL_ENTRY (L(ExitStrncpyTable), %r8, 4)

/* Case2 or Case3,  Case3 */

	.p2align 4
L(CopyVecSizeCase2OrCase3):
	test	%rdx, %rdx
	jnz	L(CopyVecSizeCase2)
L(CopyVecSizeCase3):
	add	$VEC_SIZE, %r8
	add	%rcx, %rdi
	add	%rcx, %rsi
	BRANCH_TO_JMPTBL_ENTRY (L(ExitStrncpyTable), %r8, 4)

	.p2align 4
L(CopyTwoVecSizeCase2OrCase3):
	test	%rdx, %rdx
	jnz	L(CopyTwoVecSizeCase2)
	add	%rcx, %rsi
	BRANCH_TO_JMPTBL_ENTRY (L(ExitStrncpyTable), %r8, 4)

	.p2align 4
L(CopyVecSizeTailCase2OrCase3):
	test	%rdx, %rdx
	jnz	L(CopyVecSizeTailCase2)
	add	%rcx, %rsi
	BRANCH_TO_JMPTBL_ENTRY (L(ExitStrncpyTable), %r8, 4)

	.p2align 4
L(CopyTwoVecSize1Case2OrCase3):
	add	$VEC_SIZE, %rdi
	add	$VEC_SIZE, %rsi
	sub	$VEC_SIZE, %r8
L(CopyVecSizeTail1Case2OrCase3):
	test	%rdx, %rdx
	jnz	L(CopyVecSizeTail1Case2)
	BRANCH_TO_JMPTBL_ENTRY (L(ExitStrncpyTable), %r8, 4)

# endif

/*------------End labels regarding with copying 1-VEC_SIZE bytes--and 1-(VEC_SIZE*2) bytes----*/

	.p2align 4
L(Exit1):
	mov	%dh, (%rdi)
# ifdef USE_AS_STPCPY
	lea	(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$1, %r8
	lea	1(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit2):
	mov	(%rsi), %dx
	mov	%dx, (%rdi)
# ifdef USE_AS_STPCPY
	lea	1(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$2, %r8
	lea	2(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit3):
	mov	(%rsi), %cx
	mov	%cx, (%rdi)
	mov	%dh, 2(%rdi)
# ifdef USE_AS_STPCPY
	lea	2(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$3, %r8
	lea	3(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit4):
	mov	(%rsi), %edx
	mov	%edx, (%rdi)
# ifdef USE_AS_STPCPY
	lea	3(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$4, %r8
	lea	4(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit5):
	mov	(%rsi), %ecx
	mov	%dh, 4(%rdi)
	mov	%ecx, (%rdi)
# ifdef USE_AS_STPCPY
	lea	4(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$5, %r8
	lea	5(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit6):
	mov	(%rsi), %ecx
	mov	4(%rsi), %dx
	mov	%ecx, (%rdi)
	mov	%dx, 4(%rdi)
# ifdef USE_AS_STPCPY
	lea	5(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$6, %r8
	lea	6(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit7):
	mov	(%rsi), %ecx
	mov	3(%rsi), %edx
	mov	%ecx, (%rdi)
	mov	%edx, 3(%rdi)
# ifdef USE_AS_STPCPY
	lea	6(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$7, %r8
	lea	7(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit8):
	mov	(%rsi), %rdx
	mov	%rdx, (%rdi)
# ifdef USE_AS_STPCPY
	lea	7(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$8, %r8
	lea	8(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit9):
	mov	(%rsi), %rcx
	mov	%dh, 8(%rdi)
	mov	%rcx, (%rdi)
# ifdef USE_AS_STPCPY
	lea	8(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$9, %r8
	lea	9(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit10):
	mov	(%rsi), %rcx
	mov	8(%rsi), %dx
	mov	%rcx, (%rdi)
	mov	%dx, 8(%rdi)
# ifdef USE_AS_STPCPY
	lea	9(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$10, %r8
	lea	10(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit11):
	mov	(%rsi), %rcx
	mov	7(%rsi), %edx
	mov	%rcx, (%rdi)
	mov	%edx, 7(%rdi)
# ifdef USE_AS_STPCPY
	lea	10(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$11, %r8
	lea	11(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit12):
	mov	(%rsi), %rcx
	mov	8(%rsi), %edx
	mov	%rcx, (%rdi)
	mov	%edx, 8(%rdi)
# ifdef USE_AS_STPCPY
	lea	11(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$12, %r8
	lea	12(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit13):
	mov	(%rsi), %rcx
	mov	5(%rsi), %rdx
	mov	%rcx, (%rdi)
	mov	%rdx, 5(%rdi)
# ifdef USE_AS_STPCPY
	lea	12(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$13, %r8
	lea	13(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit14):
	mov	(%rsi), %rcx
	mov	6(%rsi), %rdx
	mov	%rcx, (%rdi)
	mov	%rdx, 6(%rdi)
# ifdef USE_AS_STPCPY
	lea	13(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$14, %r8
	lea	14(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit15):
	mov	(%rsi), %rcx
	mov	7(%rsi), %rdx
	mov	%rcx, (%rdi)
	mov	%rdx, 7(%rdi)
# ifdef USE_AS_STPCPY
	lea	14(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$15, %r8
	lea	15(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit16):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	%xmm0, (%rdi)
# ifdef USE_AS_STPCPY
	lea	15(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$16, %r8
	lea	16(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit17):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	%xmm0, (%rdi)
	mov	%dh, 16(%rdi)
# ifdef USE_AS_STPCPY
	lea	16(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$17, %r8
	lea	17(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit18):
	vmovdqu	(%rsi), %xmm0
	mov	16(%rsi), %cx
	vmovdqu	%xmm0, (%rdi)
	mov	%cx, 16(%rdi)
# ifdef USE_AS_STPCPY
	lea	17(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$18, %r8
	lea	18(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit19):
	vmovdqu	(%rsi), %xmm0
	mov	15(%rsi), %ecx
	vmovdqu	%xmm0, (%rdi)
	mov	%ecx, 15(%rdi)
# ifdef USE_AS_STPCPY
	lea	18(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$19, %r8
	lea	19(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit20):
	vmovdqu	(%rsi), %xmm0
	mov	16(%rsi), %ecx
	vmovdqu	%xmm0, (%rdi)
	mov	%ecx, 16(%rdi)
# ifdef USE_AS_STPCPY
	lea	19(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$20, %r8
	lea	20(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit21):
	vmovdqu	(%rsi), %xmm0
	mov	13(%rsi), %rcx
	vmovdqu	%xmm0, (%rdi)
	mov	%rcx, 13(%rdi)
# ifdef USE_AS_STPCPY
	lea	20(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$21, %r8
	lea	21(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit22):
	vmovdqu	(%rsi), %xmm0
	mov	14(%rsi), %rcx
	vmovdqu	%xmm0, (%rdi)
	mov	%rcx, 14(%rdi)
# ifdef USE_AS_STPCPY
	lea	21(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$22, %r8
	lea	22(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit23):
	vmovdqu	(%rsi), %xmm0
	mov	15(%rsi), %rcx
	vmovdqu	%xmm0, (%rdi)
	mov	%rcx, 15(%rdi)
# ifdef USE_AS_STPCPY
	lea	22(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$23, %r8
	lea	23(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit24):
	vmovdqu	(%rsi), %xmm0
	mov	16(%rsi), %rcx
	vmovdqu	%xmm0, (%rdi)
	mov	%rcx, 16(%rdi)
# ifdef USE_AS_STPCPY
	lea	23(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$24, %r8
	lea	24(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit25):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	9(%rsi), %xmm1
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm1, 9(%rdi)
# ifdef USE_AS_STPCPY
	lea	24(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$25, %r8
	lea	25(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit26):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	10(%rsi), %xmm1
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm1, 10(%rdi)
# ifdef USE_AS_STPCPY
	lea	25(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$26, %r8
	lea	26(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit27):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	11(%rsi), %xmm1
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm1, 11(%rdi)
# ifdef USE_AS_STPCPY
	lea	26(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$27, %r8
	lea	27(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit28):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	12(%rsi), %xmm1
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm1, 12(%rdi)
# ifdef USE_AS_STPCPY
	lea	27(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$28, %r8
	lea	28(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit29):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	13(%rsi), %xmm2
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm2, 13(%rdi)
# ifdef USE_AS_STPCPY
	lea	28(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$29, %r8
	lea	29(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit30):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	14(%rsi), %xmm2
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm2, 14(%rdi)
# ifdef USE_AS_STPCPY
	lea	29(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$30, %r8
	lea	30(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit31):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	15(%rsi), %xmm2
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm2, 15(%rdi)
# ifdef USE_AS_STPCPY
	lea	30(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$31, %r8
	lea	31(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit32):
	vmovdqu	(%rsi), %ymm0
	vmovdqu	%ymm0, (%rdi)
# ifdef USE_AS_STPCPY
	lea	31(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$32, %r8
	lea	32(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit33):
	/* 0/32, 32/1 */
	vmovdqu (%rsi), %ymm0
	vmovdqu %ymm0, (%rdi)
	mov	%dh, 32(%rdi)
# ifdef USE_AS_STPCPY
	lea	32(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$33, %r8
	lea	33(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit34):
	/* 0/32, 32/2 */
	vmovdqu (%rsi), %ymm0
	mov	32(%rsi), %dx
	vmovdqu %ymm0, (%rdi)
	mov	%dx, 32(%rdi)
# ifdef USE_AS_STPCPY
	lea	33(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$34, %r8
	lea	34(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit35):
	/* 0/32, 31/4 */
	vmovdqu (%rsi), %ymm0
	mov	31(%rsi), %edx
	vmovdqu %ymm0, (%rdi)
	mov	%edx, 31(%rdi)
# ifdef USE_AS_STPCPY
	lea	34(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$35, %r8
	lea	35(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit36):
	/* 0/32, 32/4 */
	vmovdqu (%rsi), %ymm0
	mov	32(%rsi), %edx
	vmovdqu %ymm0, (%rdi)
	mov	%edx, 32(%rdi)
# ifdef USE_AS_STPCPY
	lea	35(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$36, %r8
	lea	36(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit37):
	/* 0/32, 29/8 */
	vmovdqu (%rsi), %ymm0
	mov	29(%rsi), %rdx
	vmovdqu %ymm0, (%rdi)
	mov	%rdx, 29(%rdi)
# ifdef USE_AS_STPCPY
	lea	36(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$37, %r8
	lea	37(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit38):
	/* 0/32, 30/8 */
	vmovdqu (%rsi), %ymm0
	mov	30(%rsi), %rdx
	vmovdqu %ymm0, (%rdi)
	mov	%rdx, 30(%rdi)
# ifdef USE_AS_STPCPY
	lea	37(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$38, %r8
	lea	38(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit39):
	/* 0/32, 31/8 */
	vmovdqu (%rsi), %ymm0
	mov	31(%rsi), %rdx
	vmovdqu %ymm0, (%rdi)
	mov	%rdx, 31(%rdi)
# ifdef USE_AS_STPCPY
	lea	38(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$39, %r8
	lea	39(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit40):
	/* 0/32, 32/8 */
	vmovdqu (%rsi), %ymm0
	mov	32(%rsi), %rdx
	vmovdqu %ymm0, (%rdi)
	mov	%rdx, 32(%rdi)
# ifdef USE_AS_STPCPY
	lea	39(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$40, %r8
	lea	40(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit41):
	/* 0/32, 32/8, 40/1 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 25(%rsi), %xmm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm1, 25(%rdi)
# ifdef USE_AS_STPCPY
	lea	40(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$41, %r8
	lea	41(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit42):
	/* 0/32, 32/8, 40/2 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 26(%rsi), %xmm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm1, 26(%rdi)
# ifdef USE_AS_STPCPY
	lea	41(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$42, %r8
	lea	42(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit43):
	/* 0/32, 27/16 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 27(%rsi), %xmm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm1, 27(%rdi)
# ifdef USE_AS_STPCPY
	lea	42(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$43, %r8
	lea	43(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit44):
	/* 0/32, 28/16 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 28(%rsi), %xmm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm1, 28(%rdi)
# ifdef USE_AS_STPCPY
	lea	43(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$44, %r8
	lea	44(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit45):
	/* 0/32, 29/16 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 29(%rsi), %xmm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm1, 29(%rdi)
# ifdef USE_AS_STPCPY
	lea	44(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$45, %r8
	lea	45(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit46):
	/* 0/32, 30/16 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 30(%rsi), %xmm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm1, 30(%rdi)
# ifdef USE_AS_STPCPY
	lea	45(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$46, %r8
	lea	46(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit47):
	/* 0/32, 31/16 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 31(%rsi), %xmm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm1, 31(%rdi)
# ifdef USE_AS_STPCPY
	lea	46(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$47, %r8
	lea	47(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit48):
	/* 0/32, 32/16 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 32(%rsi), %xmm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm1, 32(%rdi)
# ifdef USE_AS_STPCPY
	lea	47(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$48, %r8
	lea	48(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit49):
	/* 0/32, 32/16, 48/1 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 17(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 17(%rdi)
# ifdef USE_AS_STPCPY
	lea	48(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$49, %r8
	lea	49(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit50):
	/* 0/32, 32/16, 48/2 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 18(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 18(%rdi)
# ifdef USE_AS_STPCPY
	lea	49(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$50, %r8
	lea	50(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit51):
	/* 0/32, 32/16, 47/4 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 19(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 19(%rdi)
# ifdef USE_AS_STPCPY
	lea	50(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$51, %r8
	lea	51(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit52):
	/* 0/32, 32/16, 48/4 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 20(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 20(%rdi)
# ifdef USE_AS_STPCPY
	lea	51(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$52, %r8
	lea	52(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit53):
	/* 0/32, 32/16, 45/8 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 21(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 21(%rdi)
# ifdef USE_AS_STPCPY
	lea	52(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$53, %r8
	lea	53(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit54):
	/* 0/32, 32/16, 46/8 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 22(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 22(%rdi)
# ifdef USE_AS_STPCPY
	lea	53(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$54, %r8
	lea	54(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit55):
	/* 0/32, 32/16, 47/8 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 23(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 23(%rdi)
# ifdef USE_AS_STPCPY
	lea	54(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$55, %r8
	lea	55(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit56):
	/* 0/32, 32/16, 48/8 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 24(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 24(%rdi)
# ifdef USE_AS_STPCPY
	lea	55(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$56, %r8
	lea	56(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit57):
	/* 0/32, 25/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 25(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 25(%rdi)
# ifdef USE_AS_STPCPY
	lea	56(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$57, %r8
	lea	57(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit58):
	/* 0/32, 26/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 26(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 26(%rdi)
# ifdef USE_AS_STPCPY
	lea	57(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$58, %r8
	lea	58(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit59):
	/* 0/32, 27/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 27(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 27(%rdi)
# ifdef USE_AS_STPCPY
	lea	58(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$59, %r8
	lea	59(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit60):
	/* 0/32, 28/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 28(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 28(%rdi)
# ifdef USE_AS_STPCPY
	lea	59(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$60, %r8
	lea	60(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit61):
	/* 0/32, 29/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 29(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 29(%rdi)
# ifdef USE_AS_STPCPY
	lea	60(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$61, %r8
	lea	61(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit62):
	/* 0/32, 30/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 30(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 30(%rdi)
# ifdef USE_AS_STPCPY
	lea	61(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$62, %r8
	lea	62(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit63):
	/* 0/32, 31/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 31(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 31(%rdi)
# ifdef USE_AS_STPCPY
	lea	62(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$63, %r8
	lea	63(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit64):
	/* 0/32, 32/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 32(%rsi), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, 32(%rdi)
# ifdef USE_AS_STPCPY
	lea	63(%rdi), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$64, %r8
	lea	64(%rdi), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

# ifdef USE_AS_STRNCPY

	.p2align 4
L(StrncpyExit0):
#  ifdef USE_AS_STPCPY
	mov	%rdi, %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, (%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit1):
	mov	(%rsi), %dl
	mov	%dl, (%rdi)
#  ifdef USE_AS_STPCPY
	lea	1(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 1(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit2):
	mov	(%rsi), %dx
	mov	%dx, (%rdi)
#  ifdef USE_AS_STPCPY
	lea	2(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 2(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit3):
	mov	(%rsi), %cx
	mov	2(%rsi), %dl
	mov	%cx, (%rdi)
	mov	%dl, 2(%rdi)
#  ifdef USE_AS_STPCPY
	lea	3(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 3(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit4):
	mov	(%rsi), %edx
	mov	%edx, (%rdi)
#  ifdef USE_AS_STPCPY
	lea	4(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 4(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit5):
	mov	(%rsi), %ecx
	mov	4(%rsi), %dl
	mov	%ecx, (%rdi)
	mov	%dl, 4(%rdi)
#  ifdef USE_AS_STPCPY
	lea	5(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 5(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit6):
	mov	(%rsi), %ecx
	mov	4(%rsi), %dx
	mov	%ecx, (%rdi)
	mov	%dx, 4(%rdi)
#  ifdef USE_AS_STPCPY
	lea	6(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 6(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit7):
	mov	(%rsi), %ecx
	mov	3(%rsi), %edx
	mov	%ecx, (%rdi)
	mov	%edx, 3(%rdi)
#  ifdef USE_AS_STPCPY
	lea	7(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 7(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit8):
	mov	(%rsi), %rdx
	mov	%rdx, (%rdi)
#  ifdef USE_AS_STPCPY
	lea	8(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 8(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit9):
	mov	(%rsi), %rcx
	mov	8(%rsi), %dl
	mov	%rcx, (%rdi)
	mov	%dl, 8(%rdi)
#  ifdef USE_AS_STPCPY
	lea	9(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 9(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit10):
	mov	(%rsi), %rcx
	mov	8(%rsi), %dx
	mov	%rcx, (%rdi)
	mov	%dx, 8(%rdi)
#  ifdef USE_AS_STPCPY
	lea	10(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 10(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit11):
	mov	(%rsi), %rcx
	mov	7(%rsi), %edx
	mov	%rcx, (%rdi)
	mov	%edx, 7(%rdi)
#  ifdef USE_AS_STPCPY
	lea	11(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 11(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit12):
	mov	(%rsi), %rcx
	mov	8(%rsi), %edx
	mov	%rcx, (%rdi)
	mov	%edx, 8(%rdi)
#  ifdef USE_AS_STPCPY
	lea	12(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 12(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit13):
	mov	(%rsi), %rcx
	mov	5(%rsi), %rdx
	mov	%rcx, (%rdi)
	mov	%rdx, 5(%rdi)
#  ifdef USE_AS_STPCPY
	lea	13(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 13(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit14):
	mov	(%rsi), %rcx
	mov	6(%rsi), %rdx
	mov	%rcx, (%rdi)
	mov	%rdx, 6(%rdi)
#  ifdef USE_AS_STPCPY
	lea	14(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 14(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit15):
	mov	(%rsi), %rcx
	mov	7(%rsi), %rdx
	mov	%rcx, (%rdi)
	mov	%rdx, 7(%rdi)
#  ifdef USE_AS_STPCPY
	lea	15(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 15(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit16):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	%xmm0, (%rdi)
#  ifdef USE_AS_STPCPY
	lea	16(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 16(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit17):
	vmovdqu	(%rsi), %xmm0
	mov	16(%rsi), %cl
	vmovdqu	%xmm0, (%rdi)
	mov	%cl, 16(%rdi)
#  ifdef USE_AS_STPCPY
	lea	17(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 17(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit18):
	vmovdqu	(%rsi), %xmm0
	mov	16(%rsi), %cx
	vmovdqu	%xmm0, (%rdi)
	mov	%cx, 16(%rdi)
#  ifdef USE_AS_STPCPY
	lea	18(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 18(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit19):
	vmovdqu	(%rsi), %xmm0
	mov	15(%rsi), %ecx
	vmovdqu	%xmm0, (%rdi)
	mov	%ecx, 15(%rdi)
#  ifdef USE_AS_STPCPY
	lea	19(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 19(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit20):
	vmovdqu	(%rsi), %xmm0
	mov	16(%rsi), %ecx
	vmovdqu	%xmm0, (%rdi)
	mov	%ecx, 16(%rdi)
#  ifdef USE_AS_STPCPY
	lea	20(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 20(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit21):
	vmovdqu	(%rsi), %xmm0
	mov	13(%rsi), %rcx
	vmovdqu	%xmm0, (%rdi)
	mov	%rcx, 13(%rdi)
#  ifdef USE_AS_STPCPY
	lea	21(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 21(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit22):
	vmovdqu	(%rsi), %xmm0
	mov	14(%rsi), %rcx
	vmovdqu	%xmm0, (%rdi)
	mov	%rcx, 14(%rdi)
#  ifdef USE_AS_STPCPY
	lea	22(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 22(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit23):
	vmovdqu	(%rsi), %xmm0
	mov	15(%rsi), %rcx
	vmovdqu	%xmm0, (%rdi)
	mov	%rcx, 15(%rdi)
#  ifdef USE_AS_STPCPY
	lea	23(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 23(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit24):
	vmovdqu	(%rsi), %xmm0
	mov	16(%rsi), %rcx
	vmovdqu	%xmm0, (%rdi)
	mov	%rcx, 16(%rdi)
#  ifdef USE_AS_STPCPY
	lea	24(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 24(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit25):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	9(%rsi), %xmm1
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm1, 9(%rdi)
#  ifdef USE_AS_STPCPY
	lea	25(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 25(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit26):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	10(%rsi), %xmm1
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm1, 10(%rdi)
#  ifdef USE_AS_STPCPY
	lea	26(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 26(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit27):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	11(%rsi), %xmm1
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm1, 11(%rdi)
#  ifdef USE_AS_STPCPY
	lea	27(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 27(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit28):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	12(%rsi), %xmm1
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm1, 12(%rdi)
#  ifdef USE_AS_STPCPY
	lea	28(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 28(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit29):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	13(%rsi), %xmm2
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm2, 13(%rdi)
#  ifdef USE_AS_STPCPY
	lea	29(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 29(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit30):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	14(%rsi), %xmm2
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm2, 14(%rdi)
#  ifdef USE_AS_STPCPY
	lea	30(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 30(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit31):
	vmovdqu	(%rsi), %xmm0
	vmovdqu	15(%rsi), %xmm2
	vmovdqu	%xmm0, (%rdi)
	vmovdqu	%xmm2, 15(%rdi)
#  ifdef USE_AS_STPCPY
	lea	31(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 31(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit32):
	vmovdqu	(%rsi), %ymm0
	vmovdqu	%ymm0, (%rdi)
#  ifdef USE_AS_STPCPY
	lea	32(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 32(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit33):
	vmovdqu	(%rsi), %ymm0
	mov	32(%rsi), %cl
	vmovdqu	%ymm0, (%rdi)
	mov	%cl, 32(%rdi)
#  ifdef USE_AS_STPCPY
	lea	33(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 33(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit34):
	/*  0/32, 32/2 */
	vmovdqu (%rsi), %ymm0
	mov	32(%rsi), %cx
	vmovdqu %ymm0, (%rdi)
	mov	%cx, 32(%rdi)
#  ifdef USE_AS_STPCPY
	lea	34(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 34(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit35):
	/*  0/32, 31/4 */
	vmovdqu (%rsi), %ymm0
	mov	31(%rsi), %ecx
	vmovdqu %ymm0, (%rdi)
	mov	%ecx, 31(%rdi)
#  ifdef USE_AS_STPCPY
	lea	35(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 35(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit36):
	/*  0/32, 32/4 */
	vmovdqu (%rsi), %ymm0
	mov	32(%rsi), %ecx
	vmovdqu %ymm0, (%rdi)
	mov	%ecx, 32(%rdi)
#  ifdef USE_AS_STPCPY
	lea	36(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 36(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit37):
	/*  0/32, 29/8 */
	vmovdqu (%rsi), %ymm0
	mov	29(%rsi), %rcx
	vmovdqu %ymm0, (%rdi)
	mov	%rcx, 29(%rdi)
#  ifdef USE_AS_STPCPY
	lea	37(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 37(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit38):
	/*  0/32, 30/8 */
	vmovdqu (%rsi), %ymm0
	mov	30(%rsi), %rcx
	vmovdqu %ymm0, (%rdi)
	mov	%rcx, 30(%rdi)
#  ifdef USE_AS_STPCPY
	lea	38(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 38(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit39):
	/*  0/32, 31/8 */
	vmovdqu (%rsi), %ymm0
	mov	31(%rsi), %rcx
	vmovdqu %ymm0, (%rdi)
	mov	%rcx, 31(%rdi)
#  ifdef USE_AS_STPCPY
	lea	39(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 39(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit40):
	/*  0/32, 32/8 */
	vmovdqu (%rsi), %ymm0
	mov	32(%rsi), %rcx
	vmovdqu %ymm0, (%rdi)
	mov	%rcx, 32(%rdi)
#  ifdef USE_AS_STPCPY
	lea	40(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 40(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit41):
	/*  0/32, 32/8, 40/1 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 25(%rsi), %xmm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm1, 25(%rdi)
#  ifdef USE_AS_STPCPY
	lea	41(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 41(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit42):
	/*  0/32, 32/8, 40/2 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 26(%rsi), %xmm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm1, 26(%rdi)
#  ifdef USE_AS_STPCPY
	lea	42(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 42(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit43):
	/*  0/32, 27/16 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 27(%rsi), %xmm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm2, 27(%rdi)
#  ifdef USE_AS_STPCPY
	lea	43(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 43(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit44):
	/*  0/32, 28/16 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 28(%rsi), %xmm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm2, 28(%rdi)
#  ifdef USE_AS_STPCPY
	lea	44(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 44(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit45):
	/*  0/32, 29/16 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 29(%rsi), %xmm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm2, 29(%rdi)
#  ifdef USE_AS_STPCPY
	lea	45(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 45(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit46):
	/*  0/32, 30/16 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 30(%rsi), %xmm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm2, 30(%rdi)
#  ifdef USE_AS_STPCPY
	lea	46(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 46(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit47):
	/*  0/32, 31/16 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 31(%rsi), %xmm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm2, 31(%rdi)
#  ifdef USE_AS_STPCPY
	lea	47(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 47(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit48):
	/*  0/32, 32/16 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 32(%rsi), %xmm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %xmm2, 32(%rdi)
#  ifdef USE_AS_STPCPY
	lea	48(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 48(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit49):
	/* 0/32, 32/16, 48/1 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 17(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 17(%rdi)
#  ifdef USE_AS_STPCPY
	lea	49(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 49(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit50):
	/*  0/32, 32/16, 48/2 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 18(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 18(%rdi)
#  ifdef USE_AS_STPCPY
	lea	50(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 50(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit51):
	/*  0/32, 32/16, 47/4 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 19(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 19(%rdi)
#  ifdef USE_AS_STPCPY
	lea	51(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 51(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit52):
	/*  0/32, 32/16, 48/4 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 20(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 20(%rdi)
#  ifdef USE_AS_STPCPY
	lea	52(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 52(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit53):
	/*  0/32, 32/16, 45/8 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 21(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 21(%rdi)
#  ifdef USE_AS_STPCPY
	lea	53(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 53(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit54):
	/*  0/32, 32/16, 46/8 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 22(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 22(%rdi)
#  ifdef USE_AS_STPCPY
	lea	54(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 54(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit55):
	/* 0/32, 32/16, 47/8 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 23(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 23(%rdi)
#  ifdef USE_AS_STPCPY
	lea	55(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 55(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit56):
	/* 0/32, 32/16, 48/8 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 24(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 24(%rdi)
#  ifdef USE_AS_STPCPY
	lea	56(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 56(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit57):
	/* 0/32, 25/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 25(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 25(%rdi)
#  ifdef USE_AS_STPCPY
	lea	57(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 57(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit58):
	/* 0/32, 26/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 26(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 26(%rdi)
#  ifdef USE_AS_STPCPY
	lea	58(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 58(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit59):
	/* 0/32, 27/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 27(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 27(%rdi)
#  ifdef USE_AS_STPCPY
	lea	59(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 59(%rdi)
#  endif
	VZEROUPPER
	ret


	.p2align 4
L(StrncpyExit60):
	/* 0/32, 28/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 28(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 28(%rdi)
#  ifdef USE_AS_STPCPY
	lea	60(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 60(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit61):
	/* 0/32, 29/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 29(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 29(%rdi)
#  ifdef USE_AS_STPCPY
	lea	61(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 61(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit62):
	/* 0/32, 30/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 30(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 30(%rdi)
#  ifdef USE_AS_STPCPY
	lea	62(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 62(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit63):
	/* 0/32, 31/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 31(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 31(%rdi)
#  ifdef USE_AS_STPCPY
	lea	63(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 63(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit64):
	/* 0/32, 32/32 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 32(%rsi), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 32(%rdi)
#  ifdef USE_AS_STPCPY
	lea	64(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 64(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit65):
	/* 0/32, 32/32, 64/1 */
	vmovdqu (%rsi), %ymm0
	vmovdqu 32(%rsi), %ymm2
	mov	64(%rsi), %cl
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, 32(%rdi)
	mov	%cl, 64(%rdi)
#  ifdef USE_AS_STPCPY
	lea	65(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, 65(%rdi)
#  endif
	VZEROUPPER
	ret

#  ifndef USE_AS_STRCAT

	.p2align 4
L(Fill0):
	VZEROUPPER
	ret

	.p2align 4
L(Fill1):
	mov	%dl, (%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill2):
	mov	%dx, (%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill3):
	mov	%edx, -1(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill4):
	mov	%edx, (%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill5):
	mov	%edx, (%rdi)
	mov	%dl, 4(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill6):
	mov	%edx, (%rdi)
	mov	%dx, 4(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill7):
	mov	%rdx, -1(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill8):
	mov	%rdx, (%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill9):
	mov	%rdx, (%rdi)
	mov	%dl, 8(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill10):
	mov	%rdx, (%rdi)
	mov	%dx, 8(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill11):
	mov	%rdx, (%rdi)
	mov	%edx, 7(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill12):
	mov	%rdx, (%rdi)
	mov	%edx, 8(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill13):
	mov	%rdx, (%rdi)
	mov	%rdx, 5(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill14):
	mov	%rdx, (%rdi)
	mov	%rdx, 6(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill15):
	vmovdqu %xmmZ, -1(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill16):
	vmovdqu %xmmZ, (%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill17):
	vmovdqu %xmmZ, (%rdi)
	mov	%dl, 16(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill18):
	vmovdqu %xmmZ, (%rdi)
	mov	%dx, 16(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill19):
	vmovdqu %xmmZ, (%rdi)
	mov	%edx, 15(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill20):
	vmovdqu %xmmZ, (%rdi)
	mov	%edx, 16(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill21):
	vmovdqu %xmmZ, (%rdi)
	mov	%edx, 16(%rdi)
	mov	%dl, 20(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill22):
	vmovdqu %xmmZ, (%rdi)
	mov	%edx, 16(%rdi)
	mov	%dx, 20(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill23):
	vmovdqu %xmmZ, (%rdi)
	mov	%rdx, 15(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill24):
	vmovdqu %xmmZ, (%rdi)
	mov	%rdx, 16(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill25):
	vmovdqu %xmmZ, (%rdi)
	mov	%rdx, 16(%rdi)
	mov	%dl, 24(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill26):
	vmovdqu %xmmZ, (%rdi)
	mov	%rdx, 16(%rdi)
	mov	%dx, 24(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill27):
	vmovdqu %xmmZ, (%rdi)
	mov	%rdx, 16(%rdi)
	mov	%edx, 23(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill28):
	vmovdqu %xmmZ, (%rdi)
	mov	%rdx, 16(%rdi)
	mov	%edx, 24(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill29):
	vmovdqu %xmmZ, (%rdi)
	mov	%rdx, 16(%rdi)
	mov	%rdx, 21(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill30):
	vmovdqu %xmmZ, (%rdi)
	mov	%rdx, 16(%rdi)
	mov	%rdx, 22(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill31):
	vmovdqu %ymmZ, -1(%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(Fill32):
	vmovdqu %ymmZ, (%rdi)
	VZEROUPPER
	ret

	.p2align 4
L(CopyVecSizeUnalignedVec2):
	vmovdqu %ymm2, (%rdi, %rcx)

	.p2align 4
L(CopyVecSizeVecExit):
	bsf	%rdx, %rdx
	add	$(VEC_SIZE - 1), %r8
	add	%rcx, %rdi
#   ifdef USE_AS_STPCPY
	lea	(%rdi, %rdx), %rax
#   endif
	sub	%rdx, %r8
	lea	1(%rdi, %rdx), %rdi

	.p2align 4
L(StrncpyFillTailWithZero):
	xor	%edx, %edx
	sub	$VEC_SIZE, %r8
	jbe	L(StrncpyFillExit)

	vmovdqu %ymmZ, (%rdi)
	add	$VEC_SIZE, %rdi

	mov	%rdi, %rsi
	and	$(VEC_SIZE - 1), %rsi
	sub	%rsi, %rdi
	add	%rsi, %r8
	sub	$(VEC_SIZE * 4), %r8
	jb	L(StrncpyFillLessFourVecSize)

L(StrncpyFillLoopVmovdqa):
	vmovdqa %ymmZ, (%rdi)
	vmovdqa %ymmZ, VEC_SIZE(%rdi)
	vmovdqa %ymmZ, (VEC_SIZE * 2)(%rdi)
	vmovdqa %ymmZ, (VEC_SIZE * 3)(%rdi)
	add	$(VEC_SIZE * 4), %rdi
	sub	$(VEC_SIZE * 4), %r8
	jae	L(StrncpyFillLoopVmovdqa)

L(StrncpyFillLessFourVecSize):
	add	$(VEC_SIZE * 2), %r8
	jl	L(StrncpyFillLessTwoVecSize)
	vmovdqa %ymmZ, (%rdi)
	vmovdqa %ymmZ, VEC_SIZE(%rdi)
	add	$(VEC_SIZE * 2), %rdi
	sub	$VEC_SIZE, %r8
	jl	L(StrncpyFillExit)
	vmovdqa %ymmZ, (%rdi)
	add	$VEC_SIZE, %rdi
	BRANCH_TO_JMPTBL_ENTRY (L(FillTable), %r8, 4)

L(StrncpyFillLessTwoVecSize):
	add	$VEC_SIZE, %r8
	jl	L(StrncpyFillExit)
	vmovdqa %ymmZ, (%rdi)
	add	$VEC_SIZE, %rdi
	BRANCH_TO_JMPTBL_ENTRY (L(FillTable), %r8, 4)

L(StrncpyFillExit):
	add	$VEC_SIZE, %r8
	BRANCH_TO_JMPTBL_ENTRY (L(FillTable), %r8, 4)

/* end of ifndef USE_AS_STRCAT */
#  endif

	.p2align 4
L(UnalignedLeaveCase2OrCase3):
	test	%rdx, %rdx
	jnz	L(UnalignedFourVecSizeLeaveCase2)
L(UnalignedFourVecSizeLeaveCase3):
	lea	(VEC_SIZE * 4)(%r8), %rcx
	and	$-VEC_SIZE, %rcx
	add	$(VEC_SIZE * 3), %r8
	jl	L(CopyVecSizeCase3)
	vmovdqu %ymm4, (%rdi)
	sub	$VEC_SIZE, %r8
	jb	L(CopyVecSizeCase3)
	vmovdqu %ymm5, VEC_SIZE(%rdi)
	sub	$VEC_SIZE, %r8
	jb	L(CopyVecSizeCase3)
	vmovdqu %ymm6, (VEC_SIZE * 2)(%rdi)
	sub	$VEC_SIZE, %r8
	jb	L(CopyVecSizeCase3)
	vmovdqu %ymm7, (VEC_SIZE * 3)(%rdi)
#  ifdef USE_AS_STPCPY
	lea	(VEC_SIZE * 4)(%rdi), %rax
#  endif
#  ifdef USE_AS_STRCAT
	xor	%ch, %ch
	movb	%ch, (VEC_SIZE * 4)(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(UnalignedFourVecSizeLeaveCase2):
	xor	%ecx, %ecx
	vpcmpeqb %ymm4, %ymm0, %ymm0
	vpmovmskb %ymm0, %rdx
	add	$(VEC_SIZE * 3), %r8
	jle	L(CopyVecSizeCase2OrCase3)
	test	%rdx, %rdx
#  ifndef USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec4)
#  else
	jnz	L(CopyVecSize)
#  endif
	vpcmpeqb %ymm5, %ymm0, %ymm0
	vpmovmskb %ymm0, %rdx
	vmovdqu %ymm4, (%rdi)
	add	$VEC_SIZE, %rcx
	sub	$VEC_SIZE, %r8
	jbe	L(CopyVecSizeCase2OrCase3)
	test	%rdx, %rdx
#  ifndef USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec5)
#  else
	jnz	L(CopyVecSize)
#  endif

	vpcmpeqb %ymm6, %ymm0, %ymm0
	vpmovmskb %ymm0, %rdx
	vmovdqu %ymm5, VEC_SIZE(%rdi)
	add	$VEC_SIZE, %rcx
	sub	$VEC_SIZE, %r8
	jbe	L(CopyVecSizeCase2OrCase3)
	test	%rdx, %rdx
#  ifndef USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec6)
#  else
	jnz	L(CopyVecSize)
#  endif

	vpcmpeqb %ymm7, %ymm0, %ymm0
	vpmovmskb %ymm0, %rdx
	vmovdqu %ymm6, (VEC_SIZE * 2)(%rdi)
	lea	VEC_SIZE(%rdi, %rcx), %rdi
	lea	VEC_SIZE(%rsi, %rcx), %rsi
	bsf	%rdx, %rdx
	cmp	%r8, %rdx
	jb	L(CopyVecSizeExit)
	BRANCH_TO_JMPTBL_ENTRY (L(ExitStrncpyTable), %r8, 4)

	.p2align 4
L(ExitZero):
#  ifndef USE_AS_STRCAT
	mov	%rdi, %rax
#  endif
	VZEROUPPER
	ret

# endif

# ifndef USE_AS_STRCAT
END (STRCPY)
# else
END (STRCAT)
# endif
	.p2align 4
	.section .rodata
L(ExitTable):
	.int	JMPTBL(L(Exit1), L(ExitTable))
	.int	JMPTBL(L(Exit2), L(ExitTable))
	.int	JMPTBL(L(Exit3), L(ExitTable))
	.int	JMPTBL(L(Exit4), L(ExitTable))
	.int	JMPTBL(L(Exit5), L(ExitTable))
	.int	JMPTBL(L(Exit6), L(ExitTable))
	.int	JMPTBL(L(Exit7), L(ExitTable))
	.int	JMPTBL(L(Exit8), L(ExitTable))
	.int	JMPTBL(L(Exit9), L(ExitTable))
	.int	JMPTBL(L(Exit10), L(ExitTable))
	.int	JMPTBL(L(Exit11), L(ExitTable))
	.int	JMPTBL(L(Exit12), L(ExitTable))
	.int	JMPTBL(L(Exit13), L(ExitTable))
	.int	JMPTBL(L(Exit14), L(ExitTable))
	.int	JMPTBL(L(Exit15), L(ExitTable))
	.int	JMPTBL(L(Exit16), L(ExitTable))
	.int	JMPTBL(L(Exit17), L(ExitTable))
	.int	JMPTBL(L(Exit18), L(ExitTable))
	.int	JMPTBL(L(Exit19), L(ExitTable))
	.int	JMPTBL(L(Exit20), L(ExitTable))
	.int	JMPTBL(L(Exit21), L(ExitTable))
	.int	JMPTBL(L(Exit22), L(ExitTable))
	.int    JMPTBL(L(Exit23), L(ExitTable))
	.int	JMPTBL(L(Exit24), L(ExitTable))
	.int	JMPTBL(L(Exit25), L(ExitTable))
	.int	JMPTBL(L(Exit26), L(ExitTable))
	.int	JMPTBL(L(Exit27), L(ExitTable))
	.int	JMPTBL(L(Exit28), L(ExitTable))
	.int	JMPTBL(L(Exit29), L(ExitTable))
	.int	JMPTBL(L(Exit30), L(ExitTable))
	.int	JMPTBL(L(Exit31), L(ExitTable))
	.int	JMPTBL(L(Exit32), L(ExitTable))
	.int	JMPTBL(L(Exit33), L(ExitTable))
	.int	JMPTBL(L(Exit34), L(ExitTable))
	.int	JMPTBL(L(Exit35), L(ExitTable))
	.int	JMPTBL(L(Exit36), L(ExitTable))
	.int	JMPTBL(L(Exit37), L(ExitTable))
	.int	JMPTBL(L(Exit38), L(ExitTable))
	.int	JMPTBL(L(Exit39), L(ExitTable))
	.int	JMPTBL(L(Exit40), L(ExitTable))
	.int	JMPTBL(L(Exit41), L(ExitTable))
	.int	JMPTBL(L(Exit42), L(ExitTable))
	.int	JMPTBL(L(Exit43), L(ExitTable))
	.int	JMPTBL(L(Exit44), L(ExitTable))
	.int	JMPTBL(L(Exit45), L(ExitTable))
	.int	JMPTBL(L(Exit46), L(ExitTable))
	.int	JMPTBL(L(Exit47), L(ExitTable))
	.int	JMPTBL(L(Exit48), L(ExitTable))
	.int	JMPTBL(L(Exit49), L(ExitTable))
	.int	JMPTBL(L(Exit50), L(ExitTable))
	.int	JMPTBL(L(Exit51), L(ExitTable))
	.int	JMPTBL(L(Exit52), L(ExitTable))
	.int	JMPTBL(L(Exit53), L(ExitTable))
	.int	JMPTBL(L(Exit54), L(ExitTable))
	.int	JMPTBL(L(Exit55), L(ExitTable))
	.int	JMPTBL(L(Exit56), L(ExitTable))
	.int	JMPTBL(L(Exit57), L(ExitTable))
	.int	JMPTBL(L(Exit58), L(ExitTable))
	.int	JMPTBL(L(Exit59), L(ExitTable))
	.int	JMPTBL(L(Exit60), L(ExitTable))
	.int	JMPTBL(L(Exit61), L(ExitTable))
	.int	JMPTBL(L(Exit62), L(ExitTable))
	.int	JMPTBL(L(Exit63), L(ExitTable))
	.int	JMPTBL(L(Exit64), L(ExitTable))
# ifdef USE_AS_STRNCPY
L(ExitStrncpyTable):
	.int	JMPTBL(L(StrncpyExit0), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit1), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit2), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit3), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit4), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit5), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit6), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit7), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit8), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit9), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit10), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit11), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit12), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit13), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit14), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit15), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit16), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit18), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit19), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit20), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit21), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit22), L(ExitStrncpyTable))
	.int    JMPTBL(L(StrncpyExit23), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit24), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit25), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit26), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit27), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit28), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit29), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit30), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit32), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit34), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit35), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit36), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit37), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit38), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit39), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit40), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit41), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit42), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit43), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit44), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit45), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit46), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit47), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit48), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit49), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit50), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit51), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit52), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit53), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit54), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit55), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit56), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit57), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit58), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit59), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit60), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit61), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit62), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit64), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit65), L(ExitStrncpyTable))
#  ifndef USE_AS_STRCAT
	.p2align 4
L(FillTable):
	.int	JMPTBL(L(Fill0), L(FillTable))
	.int	JMPTBL(L(Fill1), L(FillTable))
	.int	JMPTBL(L(Fill2), L(FillTable))
	.int	JMPTBL(L(Fill3), L(FillTable))
	.int	JMPTBL(L(Fill4), L(FillTable))
	.int	JMPTBL(L(Fill5), L(FillTable))
	.int	JMPTBL(L(Fill6), L(FillTable))
	.int	JMPTBL(L(Fill7), L(FillTable))
	.int	JMPTBL(L(Fill8), L(FillTable))
	.int	JMPTBL(L(Fill9), L(FillTable))
	.int	JMPTBL(L(Fill10), L(FillTable))
	.int	JMPTBL(L(Fill11), L(FillTable))
	.int	JMPTBL(L(Fill12), L(FillTable))
	.int	JMPTBL(L(Fill13), L(FillTable))
	.int	JMPTBL(L(Fill14), L(FillTable))
	.int	JMPTBL(L(Fill15), L(FillTable))
	.int	JMPTBL(L(Fill16), L(FillTable))
	.int	JMPTBL(L(Fill17), L(FillTable))
	.int	JMPTBL(L(Fill18), L(FillTable))
	.int	JMPTBL(L(Fill19), L(FillTable))
	.int	JMPTBL(L(Fill20), L(FillTable))
	.int	JMPTBL(L(Fill21), L(FillTable))
	.int	JMPTBL(L(Fill22), L(FillTable))
	.int	JMPTBL(L(Fill23), L(FillTable))
	.int	JMPTBL(L(Fill24), L(FillTable))
	.int	JMPTBL(L(Fill25), L(FillTable))
	.int	JMPTBL(L(Fill26), L(FillTable))
	.int	JMPTBL(L(Fill27), L(FillTable))
	.int	JMPTBL(L(Fill28), L(FillTable))
	.int	JMPTBL(L(Fill29), L(FillTable))
	.int	JMPTBL(L(Fill30), L(FillTable))
	.int	JMPTBL(L(Fill31), L(FillTable))
	.int	JMPTBL(L(Fill32), L(FillTable))
#  endif
# endif
#endif
