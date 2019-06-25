/* x86 CET initializers function.
   Copyright (C) 2018-2020 Free Software Foundation, Inc.

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
   <https://www.gnu.org/licenses/>.  */

#include <unistd.h>
#include <errno.h>
#include <libintl.h>
#include <ldsodefs.h>
#include <dl-cet.h>
#include <cet-tunables.h>

/* GNU_PROPERTY_X86_FEATURE_1_IBT and GNU_PROPERTY_X86_FEATURE_1_SHSTK
   are defined in <elf.h>, which are only available for C sources.
   X86_FEATURE_1_IBT and X86_FEATURE_1_SHSTK are defined in <sysdep.h>
   which are available for both C and asm sources.  They must match.   */
#if GNU_PROPERTY_X86_FEATURE_1_IBT != X86_FEATURE_1_IBT
# error GNU_PROPERTY_X86_FEATURE_1_IBT != X86_FEATURE_1_IBT
#endif
#if GNU_PROPERTY_X86_FEATURE_1_SHSTK != X86_FEATURE_1_SHSTK
# error GNU_PROPERTY_X86_FEATURE_1_SHSTK != X86_FEATURE_1_SHSTK
#endif

static int
dl_cet_mark_legacy_region (struct link_map *l, unsigned int set)
{
  /* Mark PT_LOAD segments with PF_X in legacy code page bitmap.  */
  size_t i, phnum = l->l_phnum;
  const ElfW(Phdr) *phdr = l->l_phdr;
  unsigned long legacy_bitmap[3];
  int res = 0;

  legacy_bitmap[2] = set;
  for (i = 0; i < phnum; i++)
    if (phdr[i].p_type == PT_LOAD && (phdr[i].p_flags & PF_X))
      {
	legacy_bitmap[0] = phdr[i].p_vaddr + l->l_addr;
	legacy_bitmap[1] = phdr[i].p_memsz;
	res = dl_cet_mark_legacy_code (legacy_bitmap);
	if (res)
	  break;
      }

  return res;
}

/* Check if object M is compatible with CET.  */

static void
dl_cet_check (struct link_map *m, const char *program)
{
  /* Check how IBT should be enabled.  */
  unsigned int enable_ibt_type
    = GL(dl_x86_feature_1)[1] & ((1 << CET_MAX) - 1);
  /* Check how SHSTK should be enabled.  */
  unsigned int enable_shstk_type
    = ((GL(dl_x86_feature_1)[1] >> CET_MAX) & ((1 << CET_MAX) - 1));

  /* No legacy object check if both IBT and SHSTK are always on.  */
  if (enable_ibt_type == CET_ALWAYS_ON
      && enable_shstk_type == CET_ALWAYS_ON)
    return;

  /* Check if IBT is enabled by kernel.  */
  bool ibt_enabled
    = (GL(dl_x86_feature_1)[0] & GNU_PROPERTY_X86_FEATURE_1_IBT) != 0;
  /* Check if SHSTK is enabled by kernel.  */
  bool shstk_enabled
    = (GL(dl_x86_feature_1)[0] & GNU_PROPERTY_X86_FEATURE_1_SHSTK) != 0;

  if (ibt_enabled || shstk_enabled)
    {
      struct link_map *l = NULL;

      /* Check if IBT and SHSTK are enabled in object.  */
      bool enable_ibt = (ibt_enabled
			 && enable_ibt_type != CET_ALWAYS_OFF);
      bool enable_shstk = (shstk_enabled
			   && enable_shstk_type != CET_ALWAYS_OFF);
      if (program)
	{
	  /* Enable IBT and SHSTK only if they are enabled in executable.
	     NB: IBT and SHSTK may be disabled by environment variable:

	     GLIBC_TUNABLES=glibc.cpu.hwcaps=-IBT,-SHSTK
	   */
	  enable_ibt &= (HAS_CPU_FEATURE (IBT)
			 && (enable_ibt_type == CET_ALWAYS_ON
			     || (m->l_cet & lc_ibt) != 0));
	  enable_shstk &= (HAS_CPU_FEATURE (SHSTK)
			   && (enable_shstk_type == CET_ALWAYS_ON
			       || (m->l_cet & lc_shstk) != 0));
	}

      /* ld.so is CET-enabled by kernel.  But shared objects may not
	 support IBT nor SHSTK.  */
      if (enable_ibt || enable_shstk)
	{
	  int res;
	  unsigned int i;
	  unsigned int first_legacy, last_legacy;
	  bool need_legacy_bitmap = false;

	  i = m->l_searchlist.r_nlist;
	  while (i-- > 0)
	    {
	      /* Check each shared object to see if IBT and SHSTK are
		 enabled.  */
	      l = m->l_initfini[i];

	      if (l->l_init_called)
		continue;

#ifdef SHARED
	      /* Skip CET check for ld.so since ld.so is CET-enabled.
		 CET will be disabled later if CET isn't enabled in
		 executable.  */
	      if (l == &GL(dl_rtld_map)
		  ||  l->l_real == &GL(dl_rtld_map)
		  || (program && l == m))
		continue;
#endif

	      if (enable_ibt
		  && enable_ibt_type != CET_ALWAYS_ON
		  && !(l->l_cet & lc_ibt))
		{
		  /* Remember the first and last legacy objects.  */
		  if (!need_legacy_bitmap)
		    last_legacy = i;
		  first_legacy = i;
		  need_legacy_bitmap = true;
		}

	      /* SHSTK is enabled only if it is enabled in executable as
		 well as all shared objects.  */
	      enable_shstk &= (enable_shstk_type == CET_ALWAYS_ON
			       || (l->l_cet & lc_shstk) != 0);
	    }

	  if (need_legacy_bitmap)
	    {
	      /* Put legacy shared objects in legacy bitmap.  */
	      for (i = first_legacy; i <= last_legacy; i++)
		{
		  l = m->l_initfini[i];

		  if (l->l_init_called || (l->l_cet & lc_ibt))
		    continue;

#ifdef SHARED
		  if (l == &GL(dl_rtld_map)
		      ||  l->l_real == &GL(dl_rtld_map)
		      || (program && l == m))
		    continue;
#endif

		  /* If IBT is enabled in executable and IBT isn't enabled
		     in this shard object, mark PT_LOAD segments with PF_X
		     in legacy code page bitmap.  */
		  res = dl_cet_mark_legacy_region (l, 1);
		  if (res != 0)
		    {
		      if (program)
			_dl_fatal_printf ("%s: failed to mark legacy code region\n",
					  l->l_name);
		      else
			_dl_signal_error (-res, l->l_name, "dlopen",
					  N_("failed to mark legacy code region"));
		    }
		  l->l_cet |= lc_legacy_bitmap;
		}
	    }
	}

      bool cet_feature_changed = false;

      if (enable_ibt != ibt_enabled || enable_shstk != shstk_enabled)
	{
	  if (!program
	      && enable_shstk_type != CET_PERMISSIVE)
	    {
	      /* When SHSTK is enabled, we can't dlopening a shared
		 object without SHSTK.  */
	      if (enable_shstk != shstk_enabled)
		_dl_signal_error (EINVAL, l->l_name, "dlopen",
				  N_("shadow stack isn't enabled"));
	      return;
	    }

	  /* Disable IBT and/or SHSTK if they are enabled by kernel, but
	     disabled in executable or shared objects.  */
	  unsigned int cet_feature = 0;

	  /* Disable IBT only during program startup.  */
	  if (program && !enable_ibt)
	    cet_feature |= GNU_PROPERTY_X86_FEATURE_1_IBT;
	  if (!enable_shstk)
	    cet_feature |= GNU_PROPERTY_X86_FEATURE_1_SHSTK;

	  int res = dl_cet_disable_cet (cet_feature);
	  if (res != 0)
	    {
	      if (program)
		_dl_fatal_printf ("%s: can't disable CET\n", program);
	      else
		_dl_signal_error (-res, l->l_name, "dlopen",
				  N_("can't disable CET"));
	    }

	  /* Clear the disabled bits in dl_x86_feature_1.  */
	  GL(dl_x86_feature_1)[0] &= ~cet_feature;

	  cet_feature_changed = true;
	}

#ifdef SHARED
      if (program
	  && (!shstk_enabled
	      || enable_shstk_type != CET_PERMISSIVE)
	  && (ibt_enabled || shstk_enabled))
	{
	  /* Lock CET if IBT or SHSTK is enabled in executable.  Don't
	     lock CET if SHSTK is enabled permissively.  */
	  int res = dl_cet_lock_cet ();
	  if (res != 0)
	    _dl_fatal_printf ("%s: can't lock CET\n", program);

	  cet_feature_changed = true;
	}
#endif

      if (cet_feature_changed)
	{
	  unsigned int feature_1 = 0;
	  if (enable_ibt)
	    feature_1 |= GNU_PROPERTY_X86_FEATURE_1_IBT;
	  if (enable_shstk)
	    feature_1 |= GNU_PROPERTY_X86_FEATURE_1_SHSTK;
	  struct pthread *self = THREAD_SELF;
	  THREAD_SETMEM (self, header.feature_1, feature_1);
	}
    }
}

void
_dl_cet_unmap (struct link_map *l)
{
  if (l->l_cet & lc_legacy_bitmap)
    dl_cet_mark_legacy_region (l, 0);

  _dl_unmap (l);
}

void
_dl_cet_open_check (struct link_map *l)
{
  dl_cet_check (l, NULL);
}

#ifdef SHARED

# ifndef LINKAGE
#  define LINKAGE
# endif

LINKAGE
void
_dl_cet_check (struct link_map *main_map, const char *program)
{
  dl_cet_check (main_map, program);
}
#endif /* SHARED */
