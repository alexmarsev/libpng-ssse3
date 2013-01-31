/* ssse3_test.c - tests for SSSE3 optimised filter functions
 *
 * Copyright (c) 2012-2013 Alex Marsev
 *
 * This code is released under the libpng license.
 * For conditions of distribution and use, see the disclaimer
 * and license in png.h
 */

#include <stdio.h>
#include <malloc.h>

#include "../pngpriv.h"
#include "../pngrutil.c"

#define ROWLEN (9216 * 4)
#define ALIGNMENT 16
#define TRIES 10

#ifndef _WIN32
#include <time.h>
#include <stdlib.h>

void* _aligned_malloc(size_t size, size_t alignment) {
	void *res;

	if (posix_memalign(&res, alignment, size)) {
		res = 0;
	}

	return res;
}

void _aligned_free(void *memblock) {
	free(memblock);
}

#endif

typedef void pngfilterfunc(png_row_infop, png_bytep, png_const_bytep);

typedef struct {
	int bpp;
	pngfilterfunc *origfunc;
	pngfilterfunc *simdfunc;
	char *title;
} testcase_t;

typedef struct {
	int ok;
	double origtime;
	double simdtime;
} testres_t;

double timetest(pngfilterfunc func, png_row_infop infop, png_bytep rowp, png_const_bytep prevrowp) {
	double res;
#ifdef _WIN32
	LARGE_INTEGER start, stop, freq;

	QueryPerformanceFrequency(&freq);
	QueryPerformanceCounter(&start);
	func(infop, rowp, prevrowp);
	QueryPerformanceCounter(&stop);
	res = (double)((long double)(stop.QuadPart - start.QuadPart) / freq.QuadPart);
#else
	struct timespec start, stop;

	clock_gettime(CLOCK_REALTIME, &start);
	func(infop, rowp, prevrowp);
	clock_gettime(CLOCK_REALTIME, &stop);
	res = (double)(stop.tv_sec - start.tv_sec);
	res += (double)(stop.tv_nsec - start.tv_nsec) * 0.000000001;
#endif

	return res;
}

testres_t performtest(png_row_info info, testcase_t testcase, png_const_bytep rowp, png_const_bytep prevrowp) {
	testres_t testres;
	double simdtime[TRIES], origtime[TRIES];
	png_bytep workrow1, workrow2;
	int i;

	info.pixel_depth = testcase.bpp;
	info.width = info.rowbytes / info.pixel_depth;

	workrow1 = (png_bytep)_aligned_malloc(ROWLEN + ALIGNMENT, ALIGNMENT);
	workrow2 = (png_bytep)_aligned_malloc(ROWLEN + ALIGNMENT, ALIGNMENT);
	if (!workrow1 || !workrow2) {
		testres.simdtime = -1;
		testres.origtime = -1;
		testres.ok = -1;
	} else {
		memcpy(workrow1, rowp, ROWLEN);
		for (i = 0; i < TRIES; i++)
			simdtime[i] = timetest(testcase.simdfunc, &info, workrow1, prevrowp);

		memcpy(workrow2, rowp, ROWLEN);
		for (i = 0; i < TRIES; i++)
			origtime[i] = timetest(testcase.origfunc, &info, workrow2, prevrowp);

		testres.simdtime = simdtime[0];
		testres.origtime = origtime[0];
		for (i = 1; i < TRIES; i++) {
			if (simdtime[i] < testres.simdtime) testres.simdtime = simdtime[i];
			if (origtime[i] < testres.origtime) testres.origtime = origtime[i];
		}

		testres.ok = !memcmp(workrow1, workrow2, ROWLEN);
	}

	if (workrow1) _aligned_free(workrow1);
	if (workrow2) _aligned_free(workrow2);
	return testres;
}

int main() {
	int res;
	png_bytep rowp;
	png_bytep prevrowp;

	testcase_t testcases[] = {
		{24, png_read_filter_row_up, png_read_filter_row_up_sse2, "up"},
		{24, png_read_filter_row_sub, png_read_filter_row_sub3_ssse3, "sub3"},
		{32, png_read_filter_row_sub, png_read_filter_row_sub4_ssse3, "sub4"},
		{48, png_read_filter_row_sub, png_read_filter_row_sub6_ssse3, "sub6"},
		{64, png_read_filter_row_sub, png_read_filter_row_sub8_ssse3, "sub8"},
		{24, png_read_filter_row_avg, png_read_filter_row_avg3_ssse3, "avg3"},
		{32, png_read_filter_row_avg, png_read_filter_row_avg4_ssse3, "avg4"},
		{48, png_read_filter_row_avg, png_read_filter_row_avg6_ssse3, "avg6"},
		{64, png_read_filter_row_avg, png_read_filter_row_avg8_sse2, "avg8"},
		{24, png_read_filter_row_paeth_multibyte_pixel, png_read_filter_row_paeth3_ssse3, "paeth3"},
		{32, png_read_filter_row_paeth_multibyte_pixel, png_read_filter_row_paeth4_ssse3, "paeth4"},
		{48, png_read_filter_row_paeth_multibyte_pixel, png_read_filter_row_paeth6_ssse3, "paeth6"},
		{64, png_read_filter_row_paeth_multibyte_pixel, png_read_filter_row_paeth8_ssse3, "paeth8"},
	};

	res = 0;
	rowp = (png_bytep)_aligned_malloc(ROWLEN + ALIGNMENT, ALIGNMENT);
	prevrowp = (png_bytep)_aligned_malloc(ROWLEN + ALIGNMENT, ALIGNMENT);

	if (!rowp || !prevrowp) {
		res = 1;
	} else {
		int i;
		testres_t testres;
		png_row_info info;

		srand((unsigned)time(0));
		for (i = 0; i < (ROWLEN + ALIGNMENT) / sizeof(int); i++) {
			*(int*)(rowp + i * sizeof(int)) = rand();
			*(int*)(prevrowp + i * sizeof(int)) = rand();
		}

		info.rowbytes = ROWLEN;

#ifdef _WIN32
		SetThreadAffinityMask(GetCurrentThread(), 1);
#endif

		for (i = 0; i < sizeof(testcases) / sizeof(testcase_t); i++) {
			testres = performtest(info, testcases[i], rowp, prevrowp);

			if (testres.ok) {
				printf("%s: %f/%fs (simd/orig)\n",
				       testcases[i].title, testres.simdtime, testres.origtime);
			} else {
				printf("%s: FAIL %f/%fs (simd/orig)\n",
				       testcases[i].title, testres.simdtime, testres.origtime);
				res = 1;
			}
		}
	}

	if (rowp) _aligned_free(rowp);
	if (prevrowp) _aligned_free(prevrowp);
	return res;
}
