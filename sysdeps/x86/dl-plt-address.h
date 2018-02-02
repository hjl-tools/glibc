/* Support LD_AUDIT for indirect function calls via GOT.  x86 version.
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

/* Return PLT address of GLOB_DAT relocation RELOC to support LD_AUDIT
   for indirect function calls via GOT.  */

auto inline ElfW(Addr)
__attribute__ ((always_inline))
elf_machine_plt_address (struct link_map *map, ElfW(Addr) value,
			 const Elf_PLT_Reloc *reloc,
			 const ElfW(Sym) *const refsym)
{
  if (__glibc_unlikely (GLRO(dl_naudit) > 0)
      && map->l_info[ADDRIDX (DT_GNU_PLT)]
      && map->l_info[DT_JMPREL]
      && ELFW(ST_TYPE) (refsym->st_info) == STT_FUNC)
    {
      ElfW(Addr) jmprel = D_PTR (map, l_info[DT_JMPREL]);
      const Elf_PLT_Reloc *pltrel_start = (const void *) jmprel;
      const Elf_PLT_Reloc *pltrel_end
	= (const void *) (jmprel + map->l_info[DT_PLTRELSZ]->d_un.d_val);
      const Elf_PLT_Reloc *r;
      /* Find JUMP_SLOT relocation against the same function and use its
	 PLT slot as the function address.  NB: JUMP_SLOT relocations
	 are for .got.plt section and GLOB_DAT relocations are for
	 .got section.  */
      for (r = pltrel_start; r < pltrel_end; r++)
	if (ELFW(R_SYM) (r->r_info) == ELFW(R_SYM) (reloc->r_info))
	  {
	    /* D_PTR gets the relocated address.  */
	    ElfW(Addr) got = D_PTR (map, l_info[DT_PLTGOT]);
	    ElfW(Addr) got_size
	      = map->l_info[VALIDX (DT_GNU_PLTGOTSZ)]->d_un.d_val;
	    /* Adjust r_offset with load address.  */
	    ElfW(Addr) r_offset = map->l_addr + r->r_offset;
	    /* Verify that this is a GOT relocation.  */
	    if (r_offset >= (got + 3 * SIZEOF_GOT_ENTRY)
		&& r_offset < (got + got_size))
	      {
		ElfW(Addr) got_offset = r_offset - got;
		/* Get the GOT slot.  */
		ElfW(Addr) got_slot = got_offset / SIZEOF_GOT_ENTRY;
		/* Subtract the first 3 reserved GOT entries.  */
		got_slot = got_slot - 3;
		/* Compute the PLT offset.  */
		ElfW(Addr) plt_offset
		  = (got_slot
		     * map->l_info[VALIDX (DT_GNU_PLTENT)]->d_un.d_val);
		/* Add PLT0 slot.  */
		plt_offset
		  += map->l_info[VALIDX (DT_GNU_PLT0SZ)]->d_un.d_val;
		/* Verify that this is a PLT slot.  */
		if (plt_offset
		    < map->l_info[VALIDX (DT_GNU_PLTSZ)]->d_un.d_val)
		  value = (D_PTR (map, l_info[ADDRIDX (DT_GNU_PLT)])
			   + plt_offset);
	      }
	    break;
	  }
    }

  return value;
}
