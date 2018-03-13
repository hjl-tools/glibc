/* Save current context and install the given one.
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


/* int __swapcontext (ucontext_t *oucp, const ucontext_t *ucp);

  Saves the machine context in oucp such that when it is activated,
  it appears as if __swapcontextt() returned again, restores the
  machine context in ucp and thereby resumes execution in that
  context.

  This implementation is intended to be used for *synchronous* context
  switches only.  Therefore, it does not have to save anything
  other than the PRESERVED state.  */

ENTRY(__swapcontext)
	/* Save the preserved registers, the registers used for passing args,
	   and the return address.  */
	movq	%rbx, oRBX(%rdi)
	movq	%rbp, oRBP(%rdi)
	movq	%r12, oR12(%rdi)
	movq	%r13, oR13(%rdi)
	movq	%r14, oR14(%rdi)
	movq	%r15, oR15(%rdi)

	movq	%rdi, oRDI(%rdi)
	movq	%rsi, oRSI(%rdi)
	movq	%rdx, oRDX(%rdi)
	movq	%rcx, oRCX(%rdi)
	movq	%r8, oR8(%rdi)
	movq	%r9, oR9(%rdi)

	movq	(%rsp), %rcx
	movq	%rcx, oRIP(%rdi)
	leaq	8(%rsp), %rcx		/* Exclude the return address.  */
	movq	%rcx, oRSP(%rdi)

	/* We have separate floating-point register content memory on the
	   stack.  We use the __fpregs_mem block in the context.  Set the
	   links up correctly.  */
	leaq	oFPREGSMEM(%rdi), %rcx
	movq	%rcx, oFPREGS(%rdi)
	/* Save the floating-point environment.  */
	fnstenv	(%rcx)
	stmxcsr oMXCSR(%rdi)


	/* The syscall destroys some registers, save them.  */
	movq	%rsi, %r12
	movq	%rdi, %r9

	/* Save the current signal mask and install the new one with
	   rt_sigprocmask (SIG_BLOCK, newset, oldset,_NSIG/8).  */
	leaq	oSIGMASK(%rdi), %rdx
	leaq	oSIGMASK(%rsi), %rsi
	movl	$SIG_SETMASK, %edi
	movl	$_NSIG8,%r10d
	movl	$__NR_rt_sigprocmask, %eax
	syscall
	cmpq	$-4095, %rax		/* Check %rax for error.  */
	jae	SYSCALL_ERROR_LABEL	/* Jump to error handler if error.  */

	/* Restore destroyed register into RDX. The choice is arbitrary,
	   but leaving RDI and RSI available for use later can avoid
	   shuffling values.  */
	movq	%r12, %rdx

	/* Restore the floating-point context.  Not the registers, only the
	   rest.  */
	movq	oFPREGS(%rdx), %rcx
	fldenv	(%rcx)
	ldmxcsr oMXCSR(%rdx)

	/* Load the new stack pointer and the preserved registers.  */
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

	/* Get the current shadow stack pointer.  */
	rdsspq	%rcx

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
	movq	%rcx, %rsi
	subq	8(%rsp), %rsi
	jb	L(find_restore_token)
	cmpq	16(%rsp), %rsi
	jae	L(find_restore_token)

	/* On the original shadow stack, save the caller's shadow
	   stack so that we can jump back to the caller directly.  */
	leaq	8(%rcx), %rsi

	/* Save the current shadow stack pointer in __ssp[0].  */
	movq	%rsi, oSSP(%r9)

	jmp	L(unwind_shadow_stack)

L(find_restore_token):
	/* Save the current shadow stack pointer in __ssp[0].  */
	movq	%rcx, oSSP(%r9)

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
	/* Restore the target shadow stack.  */
	rstorssp -8(%rsi)

	/* Save restore token on the old shadow stack.  */
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
	xorl	%eax, %eax
	movq	%rax, (oSSP + 8)(%r9)
	movq	%rax, (oSSP + 16)(%r9)

	/* Setup registers used for passing args.  */
	movq	oRDI(%rdx), %rdi
	movq	oRSI(%rdx), %rsi
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
	/* Clear rax to indicate success.  NB: Don't use xorl to keep
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

	/* Setup registers used for passing args.  */
	movq	oRDI(%rdx), %rdi
	movq	oRSI(%rdx), %rsi
	movq	oRCX(%rdx), %rcx
	movq	oR8(%rdx), %r8
	movq	oR9(%rdx), %r9

	/* Setup finally %rdx.  */
	movq	oRDX(%rdx), %rdx

	/* Clear rax to indicate success.  */
	xorl	%eax, %eax
	ret
PSEUDO_END(__swapcontext)

weak_alias (__swapcontext, swapcontext)
