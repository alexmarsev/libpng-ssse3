; filter_ssse3.nasm - SSSE3 optimised filter functions

; Copyright (c) 2012-2013 Alex Marsev

; This code is released under the libpng license.
; For conditions of distribution and use, see the disclaimer and license in png.h

cpu intelnop

section .data

align 16
sub3_fill_mask  do 0x0d0f0e0d0f0e0d0f0e0d0f0e0d0f0e0d
sub4_fill_mask  do 0x0f0e0d0c0f0e0d0c0f0e0d0c0f0e0d0c
avg3_step1_mask do 0xffffffffff04ff02ff00ffffffffffff
avg3_step2_mask do 0xff08ff06ffffffffffffffffffffffff
avg3_step0_mask do 0xffffffffffffffffffffff0eff0cff0a
avg4_step1_mask do 0xff06ff04ff02ff00ffffffffffffffff
avg4_step0_mask do 0xffffffffffffffffff0eff0cff0aff08
avg_pack_mask   do 0xffffffffffffffff0e0c0a0806040200

section .code

; Registers' usage:
; 	eax - offset (negative)
; 	ebx - multipurpose
; 	ecx - multipurpose
; 	edx - previous row barrier
; 	esi - current row final barrier
; 	edi - current row barrier

%define ptrax eax
%define ptrbx ebx
%define ptrcx ecx
%define ptrdx edx
%define ptrsi esi
%define ptrdi edi
%define ptrbp ebp
%define ptrsp esp

%define ptrff 0xffffffff

%define offs ptrax
%define prevrowb ptrdx
%define rowfb ptrsi
%define rowb ptrdi

%define align_loop align 32

%macro push_regs 0
	push ptrbp
	mov ptrbp, ptrsp
	push ptrbx
	push rowb
	push rowfb
%endmacro

%macro pop_regs 0
	pop rowfb
	pop rowb
	pop ptrbx
	pop ptrbp
%endmacro

%macro init_regs 0
	mov rowb, [ptrbp+0xc]
	mov prevrowb, [ptrbp+0x10]
	mov rowfb, rowb
	mov ptrcx, [ptrbp+0x8]
	add rowfb, [ptrcx+0x4]
%endmacro

%macro prep_head 1; %1 - alignment
	mov ptrcx, rowb
	add ptrcx, %1-0x1
	and ptrcx, ptrff-%1+0x1
	cmp ptrcx, rowfb
	jnb .loop_end
	mov offs, rowb
	mov rowb, ptrcx
	sub offs, rowb
	sub prevrowb, offs
%endmacro

%macro prep_loop 1; %1 - alignment
	mov offs, rowb
	mov rowb, rowfb
%if %1>1
	and rowb, ptrff-%1+0x1
%endif
	sub offs, rowb
	jz .loop_end
	sub prevrowb, offs
%endmacro

%macro prep_tail 0
	mov offs, rowb
	mov rowb, rowfb
	sub offs, rowb
	sub prevrowb, offs
%endmacro

global png_check_cpu_for_ssse3
png_check_cpu_for_ssse3:
	push ptrbp
	mov ptrbp, ptrsp
	push ptrbx

	mov ptrax, 0x1
	cpuid
	mov ptrax, ptrcx
	and ptrax, 0x200

	pop ptrbx
	pop ptrbp
	ret
;png_check_cpu_for_ssse3 end

global png_read_filter_row_up_sse2

%macro eat_up_stubs 0
	cmp offs, -0x4
	jnle %%eat4_end
%%eat4:
	movd xmm0, [rowb+offs]
	movd xmm1, [prevrowb+offs]
	paddb xmm0, xmm1
	movd [rowb+offs], xmm0
	add offs, 0x4
	cmp offs, -0x4
	jle %%eat4
%%eat4_end:
	cmp offs, 0x0
	jnl %%ret
%%eat1:
	mov cl, byte [prevrowb+offs]
	add byte [rowb+offs], cl
	add offs, 0x1
	js %%eat1
%%ret:
%endmacro

png_read_filter_row_up_sse2:
	push_regs
	init_regs
	prep_head 16
	eat_up_stubs
	prep_loop 16

	test prevrowb, 0xf
	jnz .loop_unaligned
	align_loop
.loop_aligned:
	movdqa xmm0, [rowb+offs]
	paddb xmm0, [prevrowb+offs]
	movdqa [rowb+offs], xmm0
	add offs, 0x10
	js .loop_aligned
	jmp short .loop_end
	align_loop
.loop_unaligned:
	movdqu xmm0, [prevrowb+offs]
	paddb xmm0, [rowb+offs]
	movdqa [rowb+offs], xmm0
	add offs, 0x10
	js .loop_unaligned
.loop_end:

	prep_tail
	eat_up_stubs
	pop_regs
	ret
;png_read_filter_row_up_sse2 end

global png_read_filter_row_sub3_ssse3

%macro eat_sub3_stubs 0
	cmp offs, 0x0
	jnl %%ret
	movd ecx, xmm0
	and ecx, 0x00ffffff
%%eat1:
	add cl, [rowb+offs]
	movzx ebx, cl
	mov [rowb+offs], cl
	shl ebx, 16
	shr ecx, 8
	or ecx, ebx 
	add offs, 0x1
	js %%eat1
	movd xmm0, ecx
%%ret:
%endmacro

png_read_filter_row_sub3_ssse3:
	push_regs
	init_regs
	pxor xmm0, xmm0
	prep_head 16
	eat_sub3_stubs
	prep_loop 16

	pslldq xmm0, 13
	movdqa xmm2, [sub3_fill_mask]
	pshufb xmm0, xmm2
	align_loop
.loop:
	movdqa xmm1, [rowb+offs]
	paddb xmm0, xmm1
	pslldq xmm1, 3
	paddb xmm0, xmm1
	pslldq xmm1, 3
	paddb xmm0, xmm1
	pslldq xmm1, 3
	paddb xmm0, xmm1
	pslldq xmm1, 3
	paddb xmm0, xmm1
	pslldq xmm1, 3
	paddb xmm0, xmm1
	movdqa [rowb+offs], xmm0
	pshufb xmm0, xmm2
	add offs, 0x10
	js .loop
.loop_end:

	prep_tail
	eat_sub3_stubs
	pop_regs
	ret
;png_read_filter_row_sub3_ssse3 end

global png_read_filter_row_sub4_ssse3

%macro eat_sub4_stubs 0
	cmp offs, -0x4
	jnle %%eat4_end
%%eat4:
	movd xmm1, [rowb+offs]
	paddb xmm0, xmm1
	movd [rowb+offs], xmm0
	add offs, 0x4
	cmp offs, -0x4
	jle %%eat4
%%eat4_end:
	cmp offs, 0x0
	jnl %%ret
	movd ecx, xmm0
%%eat1:
	add cl, [rowb+offs]
	movzx ebx, cl
	mov [rowb+offs], cl
	shl ebx, 24
	shr ecx, 8
	or ecx, ebx
	add offs, 0x1
	js %%eat1
	movd xmm0, ecx
%%ret:
%endmacro

png_read_filter_row_sub4_ssse3:
	push_regs
	init_regs
	pxor xmm0, xmm0
	prep_head 16
	eat_sub4_stubs
	prep_loop 16

	pslldq xmm0, 12
	movdqa xmm2, [sub4_fill_mask]
	pshufb xmm0, xmm2
	align_loop
.loop:
	movdqa xmm1, [rowb+offs]
	paddb xmm0, xmm1
	pslldq xmm1, 4
	paddb xmm0, xmm1
	pslldq xmm1, 4
	paddb xmm0, xmm1
	pslldq xmm1, 4
	paddb xmm0, xmm1
	movdqa [rowb+offs], xmm0
	pshufb xmm0, xmm2
	add offs, 0x10
	js .loop
.loop_end:

	prep_tail
	eat_sub4_stubs
	pop_regs
	ret
;png_read_filter_row_sub4_ssse3 end

global png_read_filter_row_avg3_ssse3
png_read_filter_row_avg3_ssse3:
	push_regs
	init_regs
	prep_loop 1

	pxor xmm7, xmm7
	pxor xmm0, xmm0; prevpixel
	movdqa xmm6, [avg_pack_mask]
	movdqa xmm3, [avg3_step1_mask]
	movdqa xmm4, [avg3_step2_mask]
	movdqa xmm5, [avg3_step0_mask]
	align_loop
.loop:
	movq xmm1, [rowb+offs]
	punpcklbw xmm1, xmm7
	movq xmm2, [prevrowb+offs]
	punpcklbw xmm2, xmm7
	paddw xmm1, xmm1
	paddw xmm2, xmm0; prevrowb + prevpixel
	paddw xmm1, xmm2
	movdqa xmm0, xmm1
	psrlw xmm0, 1
	pshufb xmm0, xmm3
	paddw xmm1, xmm0
	movdqa xmm0, xmm1
	psrlw xmm0, 1	
	pshufb xmm0, xmm4
	paddw xmm1, xmm0
	psrlw xmm1, 1
	movdqa xmm0, xmm1; prevpixel in the next iteration
	pshufb xmm1, xmm6
	movq [rowb+offs], xmm1
	pshufb xmm0, xmm5
	add offs, 0x8
	js .loop
.loop_end:

	pop_regs
	ret
;png_read_filter_row_avg3_ssse3 end

global png_read_filter_row_avg4_ssse3
png_read_filter_row_avg4_ssse3:
	push_regs
	init_regs
	prep_loop 1

	pxor xmm7, xmm7
	pxor xmm0, xmm0; prevpixel
	movdqa xmm6, [avg_pack_mask]
	movdqa xmm3, [avg4_step1_mask]
	movdqa xmm4, [avg4_step0_mask]
	align_loop
.loop:
	movq xmm1, [rowb+offs]
	punpcklbw xmm1, xmm7
	movq xmm2, [prevrowb+offs]
	punpcklbw xmm2, xmm7
	paddw xmm1, xmm1
	paddw xmm2, xmm0; prevrowb + prevpixel
	paddw xmm1, xmm2
	movdqa xmm0, xmm1
	psrlw xmm0, 1
	pshufb xmm0, xmm3
	paddw xmm1, xmm0
	psrlw xmm1, 1
	movdqa xmm0, xmm1; prevpixel in the next iteration
	pshufb xmm1, xmm6
	movq [rowb+offs], xmm1
	pshufb xmm0, xmm4
	add offs, 0x8
	js .loop
.loop_end:

	pop_regs
	ret
;png_read_filter_row_avg4_ssse3 end

global png_read_filter_row_paeth3_ssse3

%macro paeth 0
	movdqa xmm3, xmm1; pa = b
	psubw xmm3, xmm2; pa = b - c
	movdqa xmm4, xmm0; pb = a
	psubw xmm4, xmm2; pb = a - c
	movdqa xmm5, xmm3; pc = pa
	paddw xmm5, xmm4; pc = pa + pb
	pabsw xmm3, xmm3; pa = abs(pa)
	pabsw xmm4, xmm4; pb = abs(pb)
	pabsw xmm5, xmm5; pc = abs(pc)
	pminsw xmm5, xmm4; pmin = min(pc, pb)
	pminsw xmm5, xmm3; pmin = min(pmin, pa)
	pcmpeqw xmm3, xmm5; pa_mask (pa == pmin)
	pcmpeqw xmm4, xmm5; pb_mask (pb == pmin)
	pand xmm0, xmm3; res = a & pa_mask
	movdqa xmm5, xmm3; tmp_mask = pa_mask
	pandn xmm5, xmm4; tmp_mask = !pa_mask & pb_mask
	pand xmm5, xmm1; b & tmp_mask
	por xmm0, xmm5; res |= b & tmp_mask
	por xmm3, xmm4; tmp_mask = pa_mask | pb_mask
	pandn xmm3, xmm2; c & !tmp_mask
	por xmm0, xmm3; res |= c & !tmp_mask
%endmacro

%macro movd34 2
	movzx ebx, word [%2]
	movzx ecx, byte [%2+2]
	shl ecx, 16
	or ebx, ecx
	movd %1, ebx
%endmacro

%macro movd43 2
	movd ebx, %2
	mov [%1], bx
	shr ebx, 16
	mov [%1+2], bl
%endmacro

png_read_filter_row_paeth3_ssse3:
	push_regs
	init_regs
	prep_loop 1

	pxor xmm7, xmm7
	pxor xmm0, xmm0; a
	pxor xmm2, xmm2; c
	align_loop
.loop:
	movd34 xmm1, prevrowb+offs; b
	punpcklbw xmm1, xmm7
	paeth
	packuswb xmm0, xmm7
	movdqa xmm2, xmm1; c in the next iteration
	movd34 xmm1, rowb+offs; x
	paddb xmm0, xmm1
	movd43 rowb+offs, xmm0
	punpcklbw xmm0, xmm7; a in the next iteration
	add offs, 0x3
	js .loop
.loop_end:

	pop_regs
	ret
;png_read_filter_row_paeth3_ssse3 end

global png_read_filter_row_paeth4_ssse3
png_read_filter_row_paeth4_ssse3:
	push_regs
	init_regs
	prep_loop 1

	pxor xmm7, xmm7
	pxor xmm0, xmm0; a
	pxor xmm2, xmm2; c
	align_loop
.loop:
	movd xmm1, [prevrowb+offs]; b
	punpcklbw xmm1, xmm7
	paeth
	packuswb xmm0, xmm7
	movdqa xmm2, xmm1; c in the next iteration
	movd xmm1, [rowb+offs]; x
	paddb xmm0, xmm1
	movd [rowb+offs], xmm0
	punpcklbw xmm0, xmm7; a in the next iteration
	add offs, 0x4
	js .loop
.loop_end:

	pop_regs
	ret
;png_read_filter_row_paeth4_ssse3 end
