/* Install given context.
   Copyright (C) 2002-2018 Free Software Foundation, Inc.
   This file is part of the GNU C Library.
   Contributed by Andreas Jaeger <aj@suse.de>, 2002.

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

#include <sysdep.h>
#include <bits/prctl.h>

#include "ucontext_i.h"


/*  int __setcontext (const ucontext_t *ucp)

  Restores the machine context in UCP and thereby resumes execution
  in that context.

  This implementation is intended to be used for *synchronous* context
  switches only.  Therefore, it does not have to restore anything
  other than the PRESERVED state.  */

ENTRY(__setcontext)
	/* Save argument since syscall will destroy it.  */
	pushq	%rdi
	cfi_adjust_cfa_offset(8)

	/* Set the signal mask with
	   rt_sigprocmask (SIG_SETMASK, mask, NULL, _NSIG/8).  */
	leaq	oSIGMASK(%rdi), %rsi
	xorl	%edx, %edx
	movl	$SIG_SETMASK, %edi
	movl	$_NSIG8,%r10d
	movl	$__NR_rt_sigprocmask, %eax
	syscall
	/* Pop the pointer into RDX. The choice is arbitrary, but
	   leaving RDI and RSI available for use later can avoid
	   shuffling values.  */
	popq	%rdx
	cfi_adjust_cfa_offset(-8)
	cmpq	$-4095, %rax		/* Check %rax for error.  */
	jae	SYSCALL_ERROR_LABEL	/* Jump to error handler if error.  */

	/* Restore the floating-point context.  Not the registers, only the
	   rest.  */
	movq	oFPREGS(%rdx), %rcx
	fldenv	(%rcx)
	ldmxcsr oMXCSR(%rdx)


	/* Load the new stack pointer, the preserved registers and
	   registers used for passing args.  */
	cfi_def_cfa(%rdx, 0)
	cfi_offset(%rbx,oRBX)
	cfi_offset(%rbp,oRBP)
	cfi_offset(%r12,oR12)
	cfi_offset(%r13,oR13)
	cfi_offset(%r14,oR14)
	cfi_offset(%r15,oR15)
	cfi_offset(%rsp,oRSP)
	cfi_offset(%rip,oRIP)

	movq	oRSP(%rdx), %rsp
	movq	oRBX(%rdx), %rbx
	movq	oRBP(%rdx), %rbp
	movq	oR12(%rdx), %r12
	movq	oR13(%rdx), %r13
	movq	oR14(%rdx), %r14
	movq	oR15(%rdx), %r15

#if SHSTK_ENABLED
	/* Check if shadow stack is enabled.  */
	testl	$X86_FEATURE_1_SHSTK, %fs:FEATURE_1_OFFSET
	jz	L(no_shstk)

	/* Get the base address and size of the default shadow stack.
	   NB: We can't cache them since CLONE syscall switches the
	   default shadow stack.  */
	sub	$24, %RSP_LP
	mov	%RSP_LP, %RSI_LP
	movl	$ARCH_CET_STATUS, %edi
	movl	$__NR_arch_prctl, %eax
	syscall
	testq	%rax, %rax
	jne	L(hlt)      /* This should never happen.  */

	/* NB: If both the target shadow stack pointer and the current
	   shadow stack pointer are on the original shadow stack, we
	   can unwind the stack.  Otherwise, find the restore token
	   pushed by rstorssp and saveprevssp to restore the target
	   shadow stack.  */
	movq	oSSP(%rdx), %rdi
	movq	%rdi, %rsi
	subq	8(%rsp), %rsi
	jb	L(find_restore_token)
	cmpq	16(%rsp), %rsi
	jae	L(find_restore_token)

	/* Check if both shadow stack pointers are on the original
	   shadow stack.  */
	rdsspq	%rcx
	movq	%rcx, %rsi
	subq	8(%rsp), %rsi
	jb	L(find_restore_token)
	cmpq	16(%rsp), %rsi
	jae	L(find_restore_token)

	jmp	L(unwind_shadow_stack)

L(find_restore_token):
	/* Save the target shadow stack pointer.  */
	movq	%rdi, %rsi
L(find_restore_token_loop):
	/* Check if there is a restore token.  */
	movq	-8(%rsi), %rax
	andq	$-8, %rax
	cmpq	%rsi, %rax
	je	L(restore_shadow_stack)

	/* Try the next slot.  */
	subq	$8, %rsi
	jne	L(find_restore_token_loop)

L(restore_shadow_stack):
	/* Pop return address from the shadow stack since setcontext
	   will not return.   */
	movq	$1, %rax
	incsspq	%rax

	/* Use the restore stoken to restore the target shadow stack.  */
	rstorssp -8(%rsi)

	/* Save the restore token on the old shadow stack.  NB: This
	   restore token may be checked by setcontext or swapcontext
	   later.  */
	saveprevssp

	/* Get the current shadow stack.  */
	rdsspq	%rcx

L(unwind_shadow_stack):
	add	$24, %RSP_LP
	/* Unwind the shadow stack.  */
	subq	%rdi, %rcx
	je	L(skip_unwind_shadow_stack)
	negq	%rcx
	shrq	$3, %rcx
	movl	$255, %esi
L(loop):
	cmpq	%rsi, %rcx
	cmovb	%rcx, %rsi
	incsspq	%rsi
	subq	%rsi, %rcx
	ja	L(loop)

L(skip_unwind_shadow_stack):
	movq	oRSI(%rdx), %rsi
	movq	oRDI(%rdx), %rdi
	movq	oRCX(%rdx), %rcx
	movq	oR8(%rdx), %r8
	movq	oR9(%rdx), %r9

	/* Get the return address set with getcontext.  */
	movq	oRIP(%rdx), %r10

	/* Setup finally %rdx.  */
	movq	oRDX(%rdx), %rdx

	/* Check if return address is valid for the case when setcontext
	   is invoked from __start_context with linked context.  */
	rdsspq	%rax
	cmpq	(%rax), %r10
	/* Clear RAX to indicate success.  NB: Don't use xorl to keep
	   EFLAGS for jne.  */
	movl    $0, %eax
	jne	L(jmp)
	/* Return to the new context if return address valid.  */
	pushq	%r10
	ret

L(jmp):
	/* Jump to the new context directly.  */
	jmp	*%r10

L(hlt):
	hlt

L(no_shstk):
#endif
	/* The following ret should return to the address set with
	getcontext.  Therefore push the address on the stack.  */
	movq	oRIP(%rdx), %rcx
	pushq	%rcx

	movq	oRSI(%rdx), %rsi
	movq	oRDI(%rdx), %rdi
	movq	oRCX(%rdx), %rcx
	movq	oR8(%rdx), %r8
	movq	oR9(%rdx), %r9

	/* Setup finally %rdx.  */
	movq	oRDX(%rdx), %rdx

	/* End FDE here, we fall into another context.  */
	cfi_endproc
	cfi_startproc

	/* Clear rax to indicate success.  */
	xorl	%eax, %eax
	ret
PSEUDO_END(__setcontext)

weak_alias (__setcontext, setcontext)
