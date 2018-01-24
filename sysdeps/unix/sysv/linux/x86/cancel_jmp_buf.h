/* Macros for cancel_jmp_buf.  Linux/x86 version.
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

/* Need the same setjmp jmp_buf layout in cancel_jmp_buf.  */
#define NEED_SETJMP_JMP_BUF_LAYOUT 1

/* Wee need to copy feature_1 in pthread_create.  */
#define THREAD_COPY_CANCEL_JMP_BUF_INFO(descr)				\
  ((descr)->header.feature_1						\
   = THREAD_GETMEM (THREAD_SELF, header.feature_1))

/* Get pointer to the priv field from THREAD_SELF, "self", and pointer
   to the cleanup buffer, "p".  If shadow stack is disabled, use the
   compatible struct __cancel_jmp_buf_tag.  */
#define UNWIND_BUF_PRIV(self,p) \
  (__extension__ ({							\
     unsigned int feature_1 = THREAD_GETMEM (self, header.feature_1);	\
     (((feature_1 & (1 << 1)) == 0)					\
      ? &((p)->compat.priv) : &((p)->full.priv));}))
