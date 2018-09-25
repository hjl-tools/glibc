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

	and	$((VEC_SIZE * 4) - 1), %ecx
	cmp	$(VEC_SIZE * 2), %ecx
	jbe	L(SourceStringAlignmentLessTwoVecSize)

	and	$-VEC_SIZE, %rsi
	and	$(VEC_SIZE - 1), %ecx

	vpcmpeqb (%rsi), %ymmZ, %ymm1
	vpmovmskb %ymm1, %edx
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
	test	%edx, %edx
	jnz	L(CopyVecSizeTail)

	vpcmpeqb VEC_SIZE(%rsi), %ymmZ, %ymm0
	vpmovmskb %ymm0, %edx

# ifdef USE_AS_STRNCPY
	add	$VEC_SIZE, %r10
	cmp	%r10, %r8
	jbe	L(CopyTwoVecSizeCase2OrCase3)
# endif
	test	%edx, %edx
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
	vpmovmskb %ymm0, %edx
	add	$VEC_SIZE, %rcx
# ifdef USE_AS_STRNCPY
	sub	$(VEC_SIZE * 3), %r8
	jbe	L(CopyVecSizeCase2OrCase3)
# endif
	test	%edx, %edx
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec2)
# else
	jnz	L(CopyVecSize)
# endif

	vmovdqa VEC_SIZE(%rsi, %rcx), %ymm3
	vmovdqu %ymm2, (%rdi, %rcx)
	vpcmpeqb %ymm3, %ymmZ, %ymm0
	vpmovmskb %ymm0, %edx
	add	$VEC_SIZE, %rcx
# ifdef USE_AS_STRNCPY
	sub	$VEC_SIZE, %r8
	jbe	L(CopyVecSizeCase2OrCase3)
# endif
	test	%edx, %edx
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec3)
# else
	jnz	L(CopyVecSize)
# endif

	vmovdqa VEC_SIZE(%rsi, %rcx), %ymm4
	vmovdqu %ymm3, (%rdi, %rcx)
	vpcmpeqb %ymm4, %ymmZ, %ymm0
	vpmovmskb %ymm0, %edx
	add	$VEC_SIZE, %rcx
# ifdef USE_AS_STRNCPY
	sub	$VEC_SIZE, %r8
	jbe	L(CopyVecSizeCase2OrCase3)
# endif
	test	%edx, %edx
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec4)
# else
	jnz	L(CopyVecSize)
# endif

	vmovdqa VEC_SIZE(%rsi, %rcx), %ymm1
	vmovdqu %ymm4, (%rdi, %rcx)
	vpcmpeqb %ymm1, %ymmZ, %ymm0
	vpmovmskb %ymm0, %edx
	add	$VEC_SIZE, %rcx
# ifdef USE_AS_STRNCPY
	sub	$VEC_SIZE, %r8
	jbe	L(CopyVecSizeCase2OrCase3)
# endif
	test	%edx, %edx
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec1)
# else
	jnz	L(CopyVecSize)
# endif

	vmovdqa VEC_SIZE(%rsi, %rcx), %ymm2
	vmovdqu %ymm1, (%rdi, %rcx)
	vpcmpeqb %ymm2, %ymmZ, %ymm0
	vpmovmskb %ymm0, %edx
	add	$VEC_SIZE, %rcx
# ifdef USE_AS_STRNCPY
	sub	$VEC_SIZE, %r8
	jbe	L(CopyVecSizeCase2OrCase3)
# endif
	test	%edx, %edx
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec2)
# else
	jnz	L(CopyVecSize)
# endif

	vmovdqa VEC_SIZE(%rsi, %rcx), %ymm3
	vmovdqu %ymm2, (%rdi, %rcx)
	vpcmpeqb %ymm3, %ymmZ, %ymm0
	vpmovmskb %ymm0, %edx
	add	$VEC_SIZE, %rcx
# ifdef USE_AS_STRNCPY
	sub	$VEC_SIZE, %r8
	jbe	L(CopyVecSizeCase2OrCase3)
# endif
	test	%edx, %edx
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
	vpmovmskb %ymm3, %edx
# ifdef USE_AS_STRNCPY
	sub	$(VEC_SIZE * 4), %r8
	jbe	L(UnalignedLeaveCase2OrCase3)
# endif
	test	%edx, %edx
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
	vpmovmskb %ymm3, %edx
# ifdef USE_AS_STRNCPY
	sub	$(VEC_SIZE * 4), %r8
	jbe	L(UnalignedLeaveCase2OrCase3)
# endif
	test	%edx, %edx
	jz	L(UnalignedFourVecSizeLoop_start)

L(UnalignedFourVecSizeLeave):
	vpcmpeqb %ymm4, %ymmZ, %ymm0
	vpmovmskb %ymm0, %edx
	test	%edx, %edx
	jnz	L(CopyVecSizeUnaligned_0)

	vpcmpeqb %ymm5, %ymmZ, %ymm1
	vpmovmskb %ymm1, %ecx
	test	%ecx, %ecx
	jnz	L(CopyVecSizeUnaligned_16)

	vpcmpeqb %ymm6, %ymmZ, %ymm0
	vpmovmskb %ymm0, %edx
	test	%edx, %edx
	jnz	L(CopyVecSizeUnaligned_32)

	vpcmpeqb %ymm7, %ymmZ, %ymm1
	vpmovmskb %ymm1, %ecx
	bsf	%ecx, %edx
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
	vpmovmskb %ymm0, %edx

# ifdef USE_AS_STRNCPY
#  if defined USE_AS_STPCPY || defined USE_AS_STRCAT
	cmp	$VEC_SIZE, %r8
#  else
	cmp	$(VEC_SIZE + 1), %r8
#  endif
	jbe	L(CopyVecSizeTail1Case2OrCase3)
# endif
	test	%edx, %edx
	jnz	L(CopyVecSizeTail1)

	vpcmpeqb %ymm2, %ymmZ, %ymm0
	vmovdqu %ymm1, (%rdi)
	vpmovmskb %ymm0, %edx

# ifdef USE_AS_STRNCPY
#  if defined USE_AS_STPCPY || defined USE_AS_STRCAT
	cmp	$(VEC_SIZE * 2), %r8
#  else
	cmp	$((VEC_SIZE * 2) + 1), %r8
#  endif
	jbe	L(CopyTwoVecSize1Case2OrCase3)
# endif
	test	%edx, %edx
	jnz	L(CopyTwoVecSize1)

	and	$-VEC_SIZE, %rsi
	and	$(VEC_SIZE - 1), %ecx
	jmp	L(UnalignVecSizeBoth)

/*------End of main part with loops---------------------*/

/* Case1 */

# if (!defined USE_AS_STRNCPY) || (defined USE_AS_STRCAT)
	.p2align 4
L(CopyVecSize):
	add	%rcx, %rdi
	add	%rcx, %rsi
	bsf	%edx, %edx
	BRANCH_TO_JMPTBL_ENTRY (L(ExitTable), %rdx, 4)
# endif
	.p2align 4
L(CopyVecSizeTail):
	add	%rcx, %rsi
	bsf	%edx, %edx
	BRANCH_TO_JMPTBL_ENTRY (L(ExitTable), %rdx, 4)

	.p2align 4
L(CopyTwoVecSize1):
	add	$VEC_SIZE, %rsi
	add	$VEC_SIZE, %rdi
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	$VEC_SIZE, %r8
# endif
L(CopyVecSizeTail1):
	bsf	%edx, %edx
	BRANCH_TO_JMPTBL_ENTRY (L(ExitTable), %rdx, 4)

	.p2align 4
L(CopyTwoVecSize):
	bsf	%edx, %edx
	add	%rcx, %rsi
	add	$VEC_SIZE, %edx
	sub	%ecx, %edx
	BRANCH_TO_JMPTBL_ENTRY (L(ExitTable), %rdx, 4)

	.p2align 4
L(CopyVecSizeUnaligned_0):
	bsf	%edx, %edx
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
	bsf	%ecx, %edx
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
	bsf	%edx, %edx
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
	bsf	%edx, %edx
	cmp	%r8d, %edx
	jb	L(CopyVecSizeExit)
	BRANCH_TO_JMPTBL_ENTRY (L(ExitStrncpyTable), %r8, 4)

	.p2align 4
L(CopyTwoVecSizeCase2):
	add	%rcx, %rsi
	bsf	%edx, %edx
	add	$VEC_SIZE, %edx
	sub	%ecx, %edx
	cmp	%r8d, %edx
	jb	L(CopyVecSizeExit)
	BRANCH_TO_JMPTBL_ENTRY (L(ExitStrncpyTable), %r8, 4)

L(CopyVecSizeTailCase2):
	add	%rcx, %rsi
	bsf	%edx, %edx
	cmp	%r8d, %edx
	jb	L(CopyVecSizeExit)
	BRANCH_TO_JMPTBL_ENTRY (L(ExitStrncpyTable), %r8, 4)

L(CopyVecSizeTail1Case2):
	bsf	%edx, %edx
	cmp	%r8d, %edx
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
L(Exit5_7):
	mov	(%rsi), %ecx
	mov	%ecx, (%rdi)
	mov	-3(%rsi, %rdx), %ecx
	mov	%ecx, -3(%rdi, %rdx)
# ifdef USE_AS_STPCPY
	lea	(%rdi, %rdx), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	%rdx, %r8
	sub	$1, %r8
	lea	1(%rdi, %rdx), %rdi
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
L(Exit9_15):
	mov	(%rsi), %rcx
	mov	-7(%rsi, %rdx), %r9
	mov	%rcx, (%rdi)
	mov	%r9, -7(%rdi, %rdx)
# ifdef USE_AS_STPCPY
	lea	(%rdi, %rdx), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	%rdx, %r8
	sub	$1, %r8
	lea	1(%rdi, %rdx), %rdi
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
L(Exit17_31):
	vmovdqu (%rsi), %xmm0
	vmovdqu -15(%rsi, %rdx), %xmm1
	vmovdqu %xmm0, (%rdi)
	vmovdqu %xmm1, -15(%rdi, %rdx)
# ifdef USE_AS_STPCPY
	lea	(%rdi, %rdx), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub %rdx, %r8
	sub $1, %r8
	lea 1(%rdi, %rdx), %rdi
	jnz L(StrncpyFillTailWithZero)
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
L(Exit33_63):
	vmovdqu (%rsi), %ymm0
	vmovdqu -31(%rsi, %rdx), %ymm1
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm1, -31(%rdi, %rdx)
# ifdef USE_AS_STPCPY
	lea	(%rdi, %rdx), %rax
# endif
# if defined USE_AS_STRNCPY && !defined USE_AS_STRCAT
	sub	%rdx, %r8
	sub	$1, %r8
	lea	1(%rdi, %rdx), %rdi
	jnz	L(StrncpyFillTailWithZero)
# endif
	VZEROUPPER
	ret

	.p2align 4
L(Exit64):
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
	movb	$0, (%rdi)
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
	movb	$0, 1(%rdi)
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
	movb	$0, 2(%rdi)
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
	movb	$0, 3(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit4_7):
	mov	(%rsi), %ecx
	mov	-4(%rsi, %r8), %edx
	mov	%ecx, (%rdi)
	mov	%edx, -4(%rdi, %r8)
#  ifdef USE_AS_STPCPY
	lea	(%rdi, %r8), %rax
#  endif
#  ifdef USE_AS_STRCAT
	movb	$0, (%rdi, %r8)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit8_14):
	mov	(%rsi), %rcx
	mov	-8(%rsi, %r8), %rdx
	mov	%rcx, (%rdi)
	mov	%rdx, -8(%rdi, %r8)
#  ifdef USE_AS_STPCPY
	lea	(%rdi, %r8), %rax
#  endif
#  ifdef USE_AS_STRCAT
	movb	$0, (%rdi, %r8)
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
	movb	$0, 15(%rdi)
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
	movb	$0, 16(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit17_31):
	vmovdqu (%rsi), %xmm0
	vmovdqu -16(%rsi, %r8), %xmm2
	vmovdqu %xmm0, (%rdi)
	vmovdqu %xmm2, -16(%rdi, %r8)
#  ifdef USE_AS_STPCPY
	lea	(%rdi, %r8), %rax
#  endif
#  ifdef USE_AS_STRCAT
	movb	$0, (%rdi, %r8)
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
	movb	$0, 24(%rdi)
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
	movb	$0, 25(%rdi)
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
	movb	$0, 26(%rdi)
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
	movb	$0, 27(%rdi)
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
	movb	$0, 28(%rdi)
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
	movb	$0, 29(%rdi)
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
	movb	$0, 30(%rdi)
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
	movb	$0, 31(%rdi)
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
	movb	$0, 32(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(StrncpyExit33_63):
	/*  0/32, 31/16 */
	vmovdqu (%rsi), %ymm0
	vmovdqu -VEC_SIZE(%rsi, %r8), %ymm2
	vmovdqu %ymm0, (%rdi)
	vmovdqu %ymm2, -VEC_SIZE(%rdi, %r8)
#  ifdef USE_AS_STPCPY
	lea	(%rdi, %r8), %rax
#  endif
#  ifdef USE_AS_STRCAT
	movb	$0, (%rdi, %r8)
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
	movb	$0, 64(%rdi)
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
	movb	$0, 65(%rdi)
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
L(Fill4_7):
	mov	%edx, (%rdi)
	mov     %edx, -4(%rdi, %r8)
	VZEROUPPER
	ret

	.p2align 4
L(Fill8_14):
	mov	%rdx, (%rdi)
	mov	%rdx, -8(%rdi, %r8)
	VZEROUPPER
	ret

	.p2align 4
L(Fill15_16):
	vmovdqu %xmmZ, -16(%rdi,%r8)
	VZEROUPPER
	ret

	.p2align 4
L(Fill17_31):
	vmovdqu %xmmZ, (%rdi)
	vmovdqu %xmmZ, -16(%rdi, %r8)
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
	bsf	%edx, %edx
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
	and	$(VEC_SIZE - 1), %esi
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
	movb	$0, (VEC_SIZE * 4)(%rdi)
#  endif
	VZEROUPPER
	ret

	.p2align 4
L(UnalignedFourVecSizeLeaveCase2):
	xor	%ecx, %ecx
	vpcmpeqb %ymm4, %ymmZ, %ymm0
	vpmovmskb %ymm0, %edx
	add	$(VEC_SIZE * 3), %r8
	jle	L(CopyVecSizeCase2OrCase3)
	test	%edx, %edx
#  ifndef USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec4)
#  else
	jnz	L(CopyVecSize)
#  endif
	vpcmpeqb %ymm5, %ymmZ, %ymm0
	vpmovmskb %ymm0, %edx
	vmovdqu %ymm4, (%rdi)
	add	$VEC_SIZE, %rcx
	sub	$VEC_SIZE, %r8
	jbe	L(CopyVecSizeCase2OrCase3)
	test	%edx, %edx
#  ifndef USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec5)
#  else
	jnz	L(CopyVecSize)
#  endif

	vpcmpeqb %ymm6, %ymmZ, %ymm0
	vpmovmskb %ymm0, %edx
	vmovdqu %ymm5, VEC_SIZE(%rdi)
	add	$VEC_SIZE, %rcx
	sub	$VEC_SIZE, %r8
	jbe	L(CopyVecSizeCase2OrCase3)
	test	%edx, %edx
#  ifndef USE_AS_STRCAT
	jnz	L(CopyVecSizeUnalignedVec6)
#  else
	jnz	L(CopyVecSize)
#  endif

	vpcmpeqb %ymm7, %ymmZ, %ymm0
	vpmovmskb %ymm0, %edx
	vmovdqu %ymm6, (VEC_SIZE * 2)(%rdi)
	lea	VEC_SIZE(%rdi, %rcx), %rdi
	lea	VEC_SIZE(%rsi, %rcx), %rsi
	bsf	%edx, %edx
	cmp	%r8d, %edx
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
	.int	JMPTBL(L(Exit5_7), L(ExitTable))
	.int	JMPTBL(L(Exit5_7), L(ExitTable))
	.int	JMPTBL(L(Exit5_7), L(ExitTable))
	.int	JMPTBL(L(Exit8), L(ExitTable))
	.int	JMPTBL(L(Exit9_15), L(ExitTable))
	.int	JMPTBL(L(Exit9_15), L(ExitTable))
	.int	JMPTBL(L(Exit9_15), L(ExitTable))
	.int	JMPTBL(L(Exit9_15), L(ExitTable))
	.int	JMPTBL(L(Exit9_15), L(ExitTable))
	.int	JMPTBL(L(Exit9_15), L(ExitTable))
	.int	JMPTBL(L(Exit9_15), L(ExitTable))
	.int	JMPTBL(L(Exit16), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit17_31), L(ExitTable))
	.int	JMPTBL(L(Exit32), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit33_63), L(ExitTable))
	.int	JMPTBL(L(Exit64), L(ExitTable))
# ifdef USE_AS_STRNCPY
L(ExitStrncpyTable):
	.int	JMPTBL(L(StrncpyExit0), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit1), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit2), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit3), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit4_7), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit4_7), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit4_7), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit4_7), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit8_14), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit8_14), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit8_14), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit8_14), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit8_14), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit8_14), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit8_14), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit15), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit16), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit17_31), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit32), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit33_63), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit64), L(ExitStrncpyTable))
	.int	JMPTBL(L(StrncpyExit65), L(ExitStrncpyTable))
#  ifndef USE_AS_STRCAT
	.p2align 4
L(FillTable):
	.int	JMPTBL(L(Fill0), L(FillTable))
	.int	JMPTBL(L(Fill1), L(FillTable))
	.int	JMPTBL(L(Fill2), L(FillTable))
	.int	JMPTBL(L(Fill3), L(FillTable))
	.int	JMPTBL(L(Fill4_7), L(FillTable))
	.int	JMPTBL(L(Fill4_7), L(FillTable))
	.int	JMPTBL(L(Fill4_7), L(FillTable))
	.int	JMPTBL(L(Fill4_7), L(FillTable))
	.int	JMPTBL(L(Fill8_14), L(FillTable))
	.int	JMPTBL(L(Fill8_14), L(FillTable))
	.int	JMPTBL(L(Fill8_14), L(FillTable))
	.int	JMPTBL(L(Fill8_14), L(FillTable))
	.int	JMPTBL(L(Fill8_14), L(FillTable))
	.int	JMPTBL(L(Fill8_14), L(FillTable))
	.int	JMPTBL(L(Fill8_14), L(FillTable))
	.int	JMPTBL(L(Fill15_16), L(FillTable))
	.int	JMPTBL(L(Fill15_16), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill17_31), L(FillTable))
	.int	JMPTBL(L(Fill32), L(FillTable))
#  endif
# endif
#endif
