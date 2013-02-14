/* ssse3_init.c - SSSE3 optimised filter functions
 *
 * Copyright (c) 2012-2013 Alex Marsev
 *
 * This code is released under the libpng license.
 * For conditions of distribution and use, see the disclaimer
 * and license in png.h
 */
#include "../pngpriv.h"

#ifdef PNG_ALIGNED_MEMORY_SUPPORTED

png_int_32 ssse3_suported = 0;
png_int_32 ssse3_support_checked = 0;
 
void png_init_filter_functions_ssse3(png_structp pp, unsigned int bpp) {
	if (!ssse3_support_checked) {
		ssse3_suported = png_check_cpu_for_ssse3();
		ssse3_support_checked = 1;
	}
	if (ssse3_suported) {
		pp->read_filter[PNG_FILTER_VALUE_UP-1] = png_read_filter_row_up_sse2;
		switch (bpp) {
			case 2:
				pp->read_filter[PNG_FILTER_VALUE_SUB-1] = png_read_filter_row_sub2_ssse3;
				pp->read_filter[PNG_FILTER_VALUE_AVG-1] = png_read_filter_row_avg2_ssse3;
				pp->read_filter[PNG_FILTER_VALUE_PAETH-1] = png_read_filter_row_paeth2_ssse3;
				break;
			case 3:
				pp->read_filter[PNG_FILTER_VALUE_SUB-1] = png_read_filter_row_sub3_ssse3;
				pp->read_filter[PNG_FILTER_VALUE_AVG-1] = png_read_filter_row_avg3_ssse3;
				pp->read_filter[PNG_FILTER_VALUE_PAETH-1] = png_read_filter_row_paeth3_ssse3;
				break;
			case 4:
				pp->read_filter[PNG_FILTER_VALUE_SUB-1] = png_read_filter_row_sub4_ssse3;
				pp->read_filter[PNG_FILTER_VALUE_AVG-1] = png_read_filter_row_avg4_ssse3;
				pp->read_filter[PNG_FILTER_VALUE_PAETH-1] = png_read_filter_row_paeth4_ssse3;
				break;
			case 6:
				pp->read_filter[PNG_FILTER_VALUE_SUB-1] = png_read_filter_row_sub6_ssse3;
				pp->read_filter[PNG_FILTER_VALUE_AVG-1] = png_read_filter_row_avg6_ssse3;
				pp->read_filter[PNG_FILTER_VALUE_PAETH-1] = png_read_filter_row_paeth6_ssse3;
				break;
			case 8:
				pp->read_filter[PNG_FILTER_VALUE_SUB-1] = png_read_filter_row_sub8_ssse3;
				pp->read_filter[PNG_FILTER_VALUE_AVG-1] = png_read_filter_row_avg8_sse2;
				pp->read_filter[PNG_FILTER_VALUE_PAETH-1] = png_read_filter_row_paeth8_ssse3;
				break;
		}
	}
}

#endif
