; filter_ssse3.nasm - SSSE3 optimised filter functions

; Copyright (c) 2012-2013 Alex Marsev

; This code is released under the libpng license.
; For conditions of distribution and use, see the disclaimer and license in png.h

cpu intelnop

section .data

align 16
sub3_fill_mask  do 0x0d0f0e0d0f0e0d0f0e0d0f0e0d0f0e0d
sub4_fill_mask  do 0x0f0e0d0c0f0e0d0c0f0e0d0c0f0e0d0c
sub6_fill_mask  do 0x0d0c0b0a0f0e0d0c0b0a0f0e0d0c0b0a
sub8_fill_mask  do 0x0f0e0d0c0b0a09080f0e0d0c0b0a0908
avg3_step1_mask do 0xffffffffff04ff02ff00ffffffffffff
avg3_step2_mask do 0xff08ff06ffffffffffffffffffffffff
avg3_step0_mask do 0xffffffffffffffffffffff0eff0cff0a
avg4_step1_mask do 0xff06ff04ff02ff00ffffffffffffffff
avg4_step0_mask do 0xffffffffffffffffff0eff0cff0aff08
avg6_step1_mask do 0xff02ff00ffffffffffffffffffffffff
avg6_step0_mask do 0xffffffffff0eff0cff0aff08ff06ff04
avg_pack_mask   do 0xffffffffffffffff0e0c0a0806040200

section .code

%ifdef __x86_64__

default rel

%define ptrax rax
%define ptrbx rbx
%define ptrcx rcx
%define ptrdx rdx
%define ptrdi rdi
%define ptrbp rbp
%define ptrsp rsp

%else

%define ptrax eax
%define ptrbx ebx
%define ptrcx ecx
%define ptrdx edx
%define ptrdi edi
%define ptrbp ebp
%define ptrsp esp

%endif

%define offs ptrax ; offset (negative)
%define prevrowb ptrdx ; previous row barrier
%define rowb ptrdi ; current row barrier
; ptrbx - multipurpose
; ptrcx - multipurpose

%define align_loop align 32

%macro push_regs 0
	push ptrbp
	mov ptrbp, ptrsp
	push ptrbx
%ifdef __x86_64__
%ifdef _WINDOWS
	push rdi
	sub rsp, 0x20
	movdqu [rsp], xmm6
	movdqu [rsp+0x10], xmm7
%endif
%else
	push edi
%endif
%endmacro

%macro pop_regs 0
%ifdef __x86_64__
%ifdef _WINDOWS
	movdqu xmm7, [rsp+0x10]
	movdqu xmm6, [rsp]
	add rsp, 0x20
	pop rdi
%endif
%else
	pop edi
%endif
	pop ptrbx
	pop ptrbp
%endmacro

%macro init_regs 0
%ifdef __x86_64__
%ifdef _WINDOWS
	mov rowb, rdx
	mov prevrowb, r8
	mov rbx, [rcx+0x8]
%else
	mov rbx, [rdi+0x8]
	mov rowb, rsi
%endif
%else
	mov rowb, [ebp+0xc]
	mov prevrowb, [ebp+0x10]
	mov ebx, [ebp+0x8]
	mov ebx, [ebx+0x4]
%endif
	mov offs, rowb
	add rowb, ptrbx
	add prevrowb, ptrbx
	sub offs, rowb
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
png_read_filter_row_up_sse2:
	push_regs
	init_regs

	align_loop
.loop:
	movdqa xmm0, [prevrowb+offs]
	paddb xmm0, [rowb+offs]
	movdqa [rowb+offs], xmm0
	add offs, 0x10
	js .loop

	pop_regs
	ret
;png_read_filter_row_up_sse2 end

global png_read_filter_row_sub3_ssse3
png_read_filter_row_sub3_ssse3:
	push_regs
	init_regs

	pxor xmm0, xmm0
	movdqa xmm2, [sub3_fill_mask]
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

	pop_regs
	ret
;png_read_filter_row_sub3_ssse3 end

global png_read_filter_row_sub4_ssse3
png_read_filter_row_sub4_ssse3:
	push_regs
	init_regs

	pxor xmm0, xmm0
	movdqa xmm2, [sub4_fill_mask]
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

	pop_regs
	ret
;png_read_filter_row_sub4_ssse3 end

global png_read_filter_row_sub6_ssse3
png_read_filter_row_sub6_ssse3:
	push_regs
	init_regs

	pxor xmm0, xmm0
	movdqa xmm2, [sub6_fill_mask]
	align_loop
.loop:
	movdqa xmm1, [rowb+offs]
	paddb xmm0, xmm1
	pslldq xmm1, 6
	paddb xmm0, xmm1
	pslldq xmm1, 6
	paddb xmm0, xmm1
	movdqa [rowb+offs], xmm0
	pshufb xmm0, xmm2
	add offs, 0x10
	js .loop

	pop_regs
	ret
;png_read_filter_row_sub6_ssse3 end

global png_read_filter_row_sub8_ssse3
png_read_filter_row_sub8_ssse3:
	push_regs
	init_regs

	pxor xmm0, xmm0
	movdqa xmm2, [sub8_fill_mask]
	align_loop
.loop:
	movdqa xmm1, [rowb+offs]
	paddb xmm0, xmm1
	pslldq xmm1, 8
	paddb xmm0, xmm1
	movdqa [rowb+offs], xmm0
	pshufb xmm0, xmm2
	add offs, 0x10
	js .loop

	pop_regs
	ret
;png_read_filter_row_sub8_ssse3 end

global png_read_filter_row_avg3_ssse3
png_read_filter_row_avg3_ssse3:
	push_regs
	init_regs

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

	pop_regs
	ret
;png_read_filter_row_avg3_ssse3 end

global png_read_filter_row_avg4_ssse3
png_read_filter_row_avg4_ssse3:
	push_regs
	init_regs

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

	pop_regs
	ret
;png_read_filter_row_avg4_ssse3 end

global png_read_filter_row_avg6_ssse3
png_read_filter_row_avg6_ssse3:
	push_regs
	init_regs

	pxor xmm7, xmm7
	pxor xmm0, xmm0; prevpixel
	movdqa xmm6, [avg_pack_mask]
	movdqa xmm3, [avg6_step1_mask]
	movdqa xmm4, [avg6_step0_mask]
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

	pop_regs
	ret
;png_read_filter_row_avg6_ssse3 end

global png_read_filter_row_avg8_sse2
png_read_filter_row_avg8_sse2:
	push_regs
	init_regs

	pxor xmm7, xmm7
	pxor xmm0, xmm0; prevpixel
	align_loop
.loop:
	movq xmm1, [rowb+offs]
	movq xmm2, [prevrowb+offs]
	punpcklbw xmm2, xmm7
	paddw xmm0, xmm2; prevrowb + prevpixel
	psrlw xmm0, 1
	packuswb xmm0, xmm7
	paddb xmm0, xmm1
	movq [rowb+offs], xmm0
	punpcklbw xmm0, xmm7; prevpixel in the next iteration
	add offs, 0x8
	js .loop

	pop_regs
	ret
;png_read_filter_row_avg8_sss2 end

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

%macro mov34 2
	movzx ebx, word [%2]
	movzx ecx, byte [%2+2]
	shl ecx, 16
	or ebx, ecx
	movd %1, ebx
%endmacro

%macro mov43 2
	movd ebx, %2
	mov [%1], bx
	shr ebx, 16
	mov [%1+2], bl
%endmacro

png_read_filter_row_paeth3_ssse3:
	push_regs
	init_regs

	pxor xmm7, xmm7
	pxor xmm0, xmm0; a
	pxor xmm2, xmm2; c
	align_loop
.loop:
	mov34 xmm1, prevrowb+offs; b
	punpcklbw xmm1, xmm7
	paeth
	packuswb xmm0, xmm7
	movdqa xmm2, xmm1; c in the next iteration
	mov34 xmm1, rowb+offs; x
	paddb xmm0, xmm1
	mov43 rowb+offs, xmm0
	punpcklbw xmm0, xmm7; a in the next iteration
	add offs, 0x3
	js .loop

	pop_regs
	ret
;png_read_filter_row_paeth3_ssse3 end

global png_read_filter_row_paeth4_ssse3
png_read_filter_row_paeth4_ssse3:
	push_regs
	init_regs

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

	pop_regs
	ret
;png_read_filter_row_paeth4_ssse3 end

global png_read_filter_row_paeth6_ssse3

%macro mov68 2
	movd %1, [%2]
	movzx ebx, word [%2+4]
	movd xmm6, ebx
	punpckldq %1, xmm6
%endmacro

%macro mov86 2
	movd [%1], %2
	movdqa xmm6, %2
	psrldq xmm6, 4
	movd ebx, xmm6
	mov [%1+4], bx
%endmacro

png_read_filter_row_paeth6_ssse3:
	push_regs
	init_regs

	pxor xmm7, xmm7
	pxor xmm0, xmm0; a
	pxor xmm2, xmm2; c
	align_loop
.loop:
	mov68 xmm1, prevrowb+offs; b
	punpcklbw xmm1, xmm7
	paeth
	packuswb xmm0, xmm7
	movdqa xmm2, xmm1; c in the next iteration
	mov68 xmm1, rowb+offs; x
	paddb xmm0, xmm1
	mov86 rowb+offs, xmm0
	punpcklbw xmm0, xmm7; a in the next iteration
	add offs, 0x6
	js .loop

	pop_regs
	ret
;png_read_filter_row_paeth6_ssse3 end

global png_read_filter_row_paeth8_ssse3
png_read_filter_row_paeth8_ssse3:
	push_regs
	init_regs

	pxor xmm7, xmm7
	pxor xmm0, xmm0; a
	pxor xmm2, xmm2; c
	align_loop
.loop:
	movq xmm1, [prevrowb+offs]; b
	punpcklbw xmm1, xmm7
	paeth
	packuswb xmm0, xmm7
	movdqa xmm2, xmm1; c in the next iteration
	movq xmm1, [rowb+offs]; x
	paddb xmm0, xmm1
	movq [rowb+offs], xmm0
	punpcklbw xmm0, xmm7; a in the next iteration
	add offs, 0x8
	js .loop

	pop_regs
	ret
;png_read_filter_row_paeth8_ssse3 end
