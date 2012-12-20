/* ssse3_test.c - tests for SSSE3 optimised filter functions
 *
 * Copyright (c) 2012 Alex Marsev
 *
 * This code is released under the libpng license.
 * For conditions of distribution and use, see the disclaimer
 * and license in png.h
 */

#include <stdio.h>
#include <malloc.h>

#include "../pngpriv.h"
#include "../pngrutil.c"

#define ROWLEN (3072 * 4)
#define ALIGNMENT 16
#define TRIES 10

// TODO make it non-win32 friendly

typedef void pngfilterfunc(png_row_infop, png_bytep, png_const_bytep);

typedef struct {
	int bpp;
	pngfilterfunc *origfunc;
	pngfilterfunc *simdfunc;
	char *title;
} testcase_t;

typedef struct {
	int ok;
	int time1;
	int time2;
} testres_t;

int timetest(pngfilterfunc func, png_row_infop infop, png_bytep rowp, png_const_bytep prevrowp) {
	LARGE_INTEGER start, stop, freq;
	int nstime;
	QueryPerformanceFrequency(&freq);
	QueryPerformanceCounter(&start);
	func(infop, rowp, prevrowp);
	QueryPerformanceCounter(&stop);
	nstime = (int)((stop.QuadPart - start.QuadPart) * 1000000000 / freq.QuadPart);
	return nstime;
}

testres_t performtest(png_row_info info, testcase_t testcase, png_const_bytep rowp, png_const_bytep prevrowp,
	int row_unalign, int prevrow_unalign)
{
	png_bytep workrow1, workrow2;
	int i, time1[TRIES], time2[TRIES];
	testres_t testres;

	row_unalign %= ALIGNMENT;
	prevrow_unalign %= ALIGNMENT;
	info.pixel_depth = testcase.bpp;

	workrow1 = (png_bytep)_aligned_malloc(ROWLEN + ALIGNMENT, ALIGNMENT);
	workrow2 = (png_bytep)_aligned_malloc(ROWLEN + ALIGNMENT, ALIGNMENT);
	if (!workrow1 || !workrow2) {
		testres.time1 = -1;
		testres.time2 = -1;
		testres.ok = -1;
	} else {
		memcpy(workrow1, rowp, ROWLEN + ALIGNMENT);
		for (i = 0; i < TRIES; i++)
			time1[i] = timetest(testcase.simdfunc, &info, workrow1 + row_unalign, prevrowp + prevrow_unalign);
		memcpy(workrow2, rowp, ROWLEN + ALIGNMENT);
		for (i = 0; i < TRIES; i++)
			time2[i] = timetest(testcase.origfunc, &info, workrow2 + row_unalign, prevrowp + prevrow_unalign);

		testres.time1 = time1[0];
		testres.time2 = time2[0];
		for (i = 1; i < TRIES; i++) {
			if (time1[i] < testres.time1) testres.time1 = time1[i];
			if (time2[i] < testres.time2) testres.time2 = time2[i];
		}

		testres.ok = !memcmp(workrow1, workrow2, ROWLEN + ALIGNMENT);
	}
	if (workrow1) _aligned_free(workrow1);
	if (workrow2) _aligned_free(workrow2);
	return testres;
}

int main() {
	png_byte *rowp = (png_byte*)_aligned_malloc(ROWLEN + ALIGNMENT, ALIGNMENT);
	png_byte *prevrowp = (png_byte*)_aligned_malloc(ROWLEN + ALIGNMENT, ALIGNMENT);
	int res = 0;

	testcase_t testcases[] = {
		{24, png_read_filter_row_up, png_read_filter_row_up_sse2, "up"},
		{24, png_read_filter_row_sub, png_read_filter_row_sub3_ssse3, "sub3"},
		{32, png_read_filter_row_sub, png_read_filter_row_sub4_ssse3, "sub4"},
		{24, png_read_filter_row_avg, png_read_filter_row_avg3_ssse3, "avg3"},
		{32, png_read_filter_row_avg, png_read_filter_row_avg4_ssse3, "avg4"},
		{24, png_read_filter_row_paeth_multibyte_pixel, png_read_filter_row_paeth3_ssse3, "paeth3"},
		{32, png_read_filter_row_paeth_multibyte_pixel, png_read_filter_row_paeth4_ssse3, "paeth4"},
	};

	if (!rowp || !prevrowp) {
		res = 1;
	} else {
		{
			png_byte *rowi = rowp, *prevrowi = prevrowp;
			
			srand((unsigned)time(0));
			while(rowi <= rowp + ROWLEN + ALIGNMENT + sizeof(int)) {
				*(int*)rowi = rand();
				rowi += sizeof(int);
			}
			while(prevrowi <= prevrowp + ROWLEN + ALIGNMENT + sizeof(int)) {
				*(int*)prevrowi = rand();
				prevrowi += sizeof(int);
			}
		}
		{
			int i, row_unalign, prevrow_unalign;
			png_row_info info;
			testres_t testres;
			info.rowbytes = ROWLEN;

			SetThreadAffinityMask(GetCurrentThread(), 1);
			
			for (row_unalign = 0; row_unalign <= 1; row_unalign++) {
				for (prevrow_unalign = 0; prevrow_unalign <= 1; prevrow_unalign++) {
					printf("%d %d unaligned\n", row_unalign, prevrow_unalign);
					for (i = 0; i < sizeof(testcases) / sizeof(testcase_t); i++) {
						testres = performtest(info, testcases[i], rowp, prevrowp, row_unalign, prevrow_unalign);
						if (testres.ok) {
							printf("%s: %d/%dns (simd/orig)\n", testcases[i].title, testres.time1, testres.time2);
						} else {
							printf("%s: FAIL %d/%dns (simd/orig)\n", testcases[i].title, testres.time1, testres.time2);
							res = 1;
						}
					}
				}
			}
		}
	}
	if (rowp) _aligned_free(rowp);
	if (prevrowp) _aligned_free(prevrowp);
	return res;
}
