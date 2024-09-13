# distutils: define_macros=NPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION
# cython: boundscheck=False
# cython: wraparound=False
# cython: initializedcheck=False
# cython: cdivision=True
# cython: nonecheck=False
# cython: language_level=3

# from interpolation cimport interpolate

import numpy as np
cimport numpy as np
cimport cython

from libc.math cimport floor, ceil, sqrt, fabs, sin, M_PI
from cython.parallel cimport prange

DEF LANCZOS_A = 4
DEF SIZE_LANCZOS_TMP = LANCZOS_A * 2 - 1

cdef double[64][64] temp = [
    [ 1,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [-3,  3, 0, 0, 0, 0, 0, 0,-2,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 2,  -2, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [-3,  0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2, 0,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0,-3, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2, 0,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 9,  -9,-9, 9, 0, 0, 0, 0, 6, 3,-6,-3, 0, 0, 0, 0, 6,-6, 3,-3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [-6,  6, 6,-6, 0, 0, 0, 0,-3,-3, 3, 3, 0, 0, 0, 0,-4, 4,-2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2,-2,-1,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 2,  0,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 2, 0,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [-6,  6, 6,-6, 0, 0, 0, 0,-4,-2, 4, 2, 0, 0, 0, 0,-3, 3,-3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2,-1,-2,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 4,  -4,-4, 4, 0, 0, 0, 0, 2, 2,-2,-2, 0, 0, 0, 0, 2,-2, 2,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-3, 3, 0, 0, 0, 0, 0, 0,-2,-1, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2,-2, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-3, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2, 0,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-3, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2, 0,-1, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9,-9,-9, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 3,-6,-3, 0, 0, 0, 0, 6,-6, 3,-3, 0, 0, 0, 0, 4, 2, 2, 1, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-6, 6, 6,-6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-3,-3, 3, 3, 0, 0, 0, 0,-4, 4,-2, 2, 0, 0, 0, 0,-2,-2,-1,-1, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-6, 6, 6,-6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-4,-2, 4, 2, 0, 0, 0, 0,-3, 3,-3, 3, 0, 0, 0, 0,-2,-1,-2,-1, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4,-4,-4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2,-2,-2, 0, 0, 0, 0, 2,-2, 2,-2, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0],
    [-3,  0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2, 0, 0, 0,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0,-3, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2, 0, 0, 0,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 9,  -9, 0, 0,-9, 9, 0, 0, 6, 3, 0, 0,-6,-3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6,-6, 0, 0, 3,-3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 2, 0, 0, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [-6,  6, 0, 0, 6,-6, 0, 0,-3,-3, 0, 0, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-4, 4, 0, 0,-2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2,-2, 0, 0,-1,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-3, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2, 0, 0, 0,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-3, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2, 0, 0, 0,-1, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9,-9, 0, 0,-9, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 3, 0, 0,-6,-3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6,-6, 0, 0, 3,-3, 0, 0, 4, 2, 0, 0, 2, 1, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-6, 6, 0, 0, 6,-6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-3,-3, 0, 0, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-4, 4, 0, 0,-2, 2, 0, 0,-2,-2, 0, 0,-1,-1, 0, 0],
    [ 9,  0,-9, 0,-9, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 0, 3, 0,-6, 0,-3, 0, 6, 0,-6, 0, 3, 0,-3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 2, 0, 2, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 9, 0,-9, 0,-9, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6, 0, 3, 0,-6, 0,-3, 0, 6, 0,-6, 0, 3, 0,-3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 2, 0, 2, 0, 1, 0],
    [-27, 27,27,-27,27,-27,-27,27,-18,-9,18, 9,18, 9,-18,-9,-18,18,-9, 9,18,-18, 9,-9,-18,18,18,-18,-9, 9, 9,-9,-12,-6,-6,-3,12, 6, 6, 3,-12,-6,12, 6,-6,-3, 6, 3,-12,12,-6, 6,-6, 6,-3, 3,-8,-4,-4,-2,-4,-2,-2,-1],
    [18,  -18,-18,18,-18,18,18,-18, 9, 9,-9,-9,-9,-9, 9, 9,12,-12, 6,-6,-12,12,-6, 6,12,-12,-12,12, 6,-6,-6, 6, 6, 6, 3, 3,-6,-6,-3,-3, 6, 6,-6,-6, 3, 3,-3,-3, 8,-8, 4,-4, 4,-4, 2,-2, 4, 4, 2, 2, 2, 2, 1, 1],
    [-6,  0, 6, 0, 6, 0,-6, 0, 0, 0, 0, 0, 0, 0, 0, 0,-3, 0,-3, 0, 3, 0, 3, 0,-4, 0, 4, 0,-2, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2, 0,-2, 0,-1, 0,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0,-6, 0, 6, 0, 6, 0,-6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-3, 0,-3, 0, 3, 0, 3, 0,-4, 0, 4, 0,-2, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2, 0,-2, 0,-1, 0,-1, 0],
    [18,  -18,-18,18,-18,18,18,-18,12, 6,-12,-6,-12,-6,12, 6, 9,-9, 9,-9,-9, 9,-9, 9,12,-12,-12,12, 6,-6,-6, 6, 6, 3, 6, 3,-6,-3,-6,-3, 8, 4,-8,-4, 4, 2,-4,-2, 6,-6, 6,-6, 3,-3, 3,-3, 4, 2, 4, 2, 2, 1, 2, 1],
    [-12, 12,12,-12,12,-12,-12,12,-6,-6, 6, 6, 6, 6,-6,-6,-6, 6,-6, 6, 6,-6, 6,-6,-8, 8, 8,-8,-4, 4, 4,-4,-3,-3,-3,-3, 3, 3, 3, 3,-4,-4, 4, 4,-2,-2, 2, 2,-4, 4,-4, 4,-2, 2,-2, 2,-2,-2,-2,-2,-1,-1,-1,-1],
    [ 2,  0, 0, 0,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [-6,  6, 0, 0, 6,-6, 0, 0,-4,-2, 0, 0, 4, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-3, 3, 0, 0,-3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2,-1, 0, 0,-2,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 4,  -4, 0, 0,-4, 4, 0, 0, 2, 2, 0, 0,-2,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2,-2, 0, 0, 2,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-6, 6, 0, 0, 6,-6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-4,-2, 0, 0, 4, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-3, 3, 0, 0,-3, 3, 0, 0,-2,-1, 0, 0,-2,-1, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4,-4, 0, 0,-4, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0, 0,-2,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2,-2, 0, 0, 2,-2, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0],
    [-6,  0, 6, 0, 6, 0,-6, 0, 0, 0, 0, 0, 0, 0, 0, 0,-4, 0,-2, 0, 4, 0, 2, 0,-3, 0, 3, 0,-3, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2, 0,-1, 0,-2, 0,-1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0,-6, 0, 6, 0, 6, 0,-6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,-4, 0,-2, 0, 4, 0, 2, 0,-3, 0, 3, 0,-3, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0,-2, 0,-1, 0,-2, 0,-1, 0],
    [18,  -18,-18,18,-18,18,18,-18,12, 6,-12,-6,-12,-6,12, 6,12,-12, 6,-6,-12,12,-6, 6, 9,-9,-9, 9, 9,-9,-9, 9, 8, 4, 4, 2,-8,-4,-4,-2, 6, 3,-6,-3, 6, 3,-6,-3, 6,-6, 3,-3, 6,-6, 3,-3, 4, 2, 2, 1, 4, 2, 2, 1],
    [-12, 12,12,-12,12,-12,-12,12,-6,-6, 6, 6, 6, 6,-6,-6,-8, 8,-4, 4, 8,-8, 4,-4,-6, 6, 6,-6,-6, 6, 6,-6,-4,-4,-2,-2, 4, 4, 2, 2,-3,-3, 3, 3,-3,-3, 3, 3,-4, 4,-2, 2,-4, 4,-2, 2,-2,-2,-1,-1,-2,-2,-1,-1],
    [ 4,  0,-4, 0,-4, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0,-2, 0,-2, 0, 2, 0,-2, 0, 2, 0,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [ 0,  0, 0, 0, 0, 0, 0, 0, 4, 0,-4, 0,-4, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0,-2, 0,-2, 0, 2, 0,-2, 0, 2, 0,-2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0],
    [-12, 12,12,-12,12,-12,-12,12,-8,-4, 8, 4, 8, 4,-8,-4,-6, 6,-6, 6, 6,-6, 6,-6,-6, 6, 6,-6,-6, 6, 6,-6,-4,-2,-4,-2, 4, 2, 4, 2,-4,-2, 4, 2,-4,-2, 4, 2,-3, 3,-3, 3,-3, 3,-3, 3,-2,-1,-2,-1,-2,-1,-2,-1],
    [ 8,  -8,-8, 8,-8, 8, 8,-8, 4, 4,-4,-4,-4,-4, 4, 4, 4,-4, 4,-4,-4, 4,-4, 4, 4,-4,-4, 4, 4,-4,-4, 4, 2, 2, 2, 2,-2,-2,-2,-2, 2, 2,-2,-2, 2, 2,-2,-2, 2,-2, 2,-2, 2,-2, 2,-2, 1, 1, 1, 1, 1, 1, 1, 1]
]


cdef inline image_t _G(const image_t[:, :, :] V, int x, int y, int z) noexcept nogil:
    cdef int dz, dy, dx
    dz = V.shape[0] - 1
    dy = V.shape[1] - 1
    dx = V.shape[2] - 1

    if x <  0:
        x = dx + x + 1
    elif x > dx:
        x = x - dx - 1

    if y <  0:
        y = dy + y + 1
    elif y > dy:
        y = y - dy - 1

    if z <  0:
        z = dz + z + 1
    elif z > dz:
        z = z - dz - 1

    return V[z, y, x]


cdef double nearest_neighbour_interp(const image_t[:, :, :] V, double x, double y, double z) noexcept nogil:
    return V[<int>(z), <int>(y), <int>(x)]

cdef double interpolate(const image_t[:, :, :] V, double x, double y, double z) noexcept nogil:
    cdef double xd, yd, zd
    cdef double c00, c10, c01, c11
    cdef double c0, c1
    cdef double c

    cdef int x0 = <int>floor(x)
    cdef int x1 = x0 + 1

    cdef int y0 = <int>floor(y)
    cdef int y1 = y0 + 1

    cdef int z0 = <int>floor(z)
    cdef int z1 = z0 + 1

    if x0 == x1:
        xd = 1.0
    else:
        xd = (x - x0) / (x1 - x0)

    if y0 == y1:
        yd = 1.0
    else:
        yd = (y - y0) / (y1 - y0)

    if z0 == z1:
        zd = 1.0
    else:
        zd = (z - z0) / (z1 - z0)

    c00 = _G(V, x0, y0, z0)*(1 - xd) + _G(V, x1, y0, z0)*xd
    c10 = _G(V, x0, y1, z0)*(1 - xd) + _G(V, x1, y1, z0)*xd
    c01 = _G(V, x0, y0, z1)*(1 - xd) + _G(V, x1, y0, z1)*xd
    c11 = _G(V, x0, y1, z1)*(1 - xd) + _G(V, x1, y1, z1)*xd

    c0 = c00*(1 - yd) + c10*yd
    c1 = c01*(1 - yd) + c11*yd

    c = c0*(1 - zd) + c1*zd

    return c


cdef inline double lanczos3_L(double x, int a) noexcept nogil:
    if x == 0:
        return 1.0
    elif -a <= x < a:
        return (a * sin(M_PI * x) * sin(M_PI * (x / a)))/(M_PI**2 * x**2)
    else:
        return 0.0


cdef double lanczos3(const image_t[:, :, :] V, double x, double y, double z) noexcept nogil:
    cdef int a = LANCZOS_A

    cdef int xd = <int>floor(x)
    cdef int yd = <int>floor(y)
    cdef int zd = <int>floor(z)

    cdef int xi = xd - a + 1
    cdef int xf = xd + a

    cdef int yi = yd - a + 1
    cdef int yf = yd + a

    cdef int zi = zd - a + 1
    cdef int zf = zd + a

    cdef double lx = 0.0
    cdef double ly = 0.0
    cdef double lz = 0.0

    cdef double[SIZE_LANCZOS_TMP][SIZE_LANCZOS_TMP] temp_x
    cdef double[SIZE_LANCZOS_TMP] temp_y

    cdef int i, j, k
    cdef int m, n, o

    m = 0
    for k in range(zi, zf):
        n = 0
        for j in range(yi, yf):
            lx = 0
            for i in range(xi, xf):
                lx += _G(V, i, j, k) * lanczos3_L(x - i, a)
            temp_x[m][n] = lx
            n += 1
        m += 1

    m = 0
    for k in range(zi, zf):
        n = 0
        ly = 0
        for j in range(yi, yf):
            ly += temp_x[m][n] * lanczos3_L(y - j, a)
            n += 1
        temp_y[m] = ly
        m += 1

    m = 0
    for k in range(zi, zf):
        lz += temp_y[m] * lanczos3_L(z - k, a)
        m += 1

    return lz




cdef void calc_coef_tricub(image_t[:, :, :] V, double x, double y, double z, double [64] coef) noexcept nogil:
    cdef int xi = <int>floor(x)
    cdef int yi = <int>floor(y)
    cdef int zi = <int>floor(z)

    cdef double[64] _x

    cdef int i, j

    _x[0] = _G(V, xi, yi, zi)
    _x[1] = _G(V, xi + 1, yi, zi)
    _x[2] = _G(V, xi, yi + 1, zi)
    _x[3] = _G(V, xi + 1, yi + 1, zi)
    _x[4] = _G(V, xi, yi, zi + 1)
    _x[5] = _G(V, xi + 1, yi, zi + 1)
    _x[6] = _G(V, xi, yi + 1, zi + 1)
    _x[7] = _G(V, xi + 1, yi + 1, zi + 1)

    _x[8]  = 0.5*(_G(V,  xi+1,yi,zi)      -  _G(V, xi-1, yi,   zi))
    _x[9]  = 0.5*(_G(V,  xi+2,yi,zi)      -  _G(V, xi,   yi,   zi))
    _x[10] = 0.5*(_G(V, xi+1, yi+1,zi)    -  _G(V,  xi-1, yi+1, zi))
    _x[11] = 0.5*(_G(V, xi+2, yi+1,zi)    -  _G(V,  xi,   yi+1, zi))
    _x[12] = 0.5*(_G(V, xi+1, yi,zi+1)    -  _G(V,  xi-1, yi,   zi+1))
    _x[13] = 0.5*(_G(V, xi+2, yi,zi+1)    -  _G(V,  xi,   yi,   zi+1))
    _x[14] = 0.5*(_G(V, xi+1, yi+1,zi+1)  -  _G(V,  xi-1, yi+1, zi+1))
    _x[15] = 0.5*(_G(V, xi+2, yi+1,zi+1)  -  _G(V,  xi,   yi+1, zi+1))
    _x[16] = 0.5*(_G(V, xi,   yi+1,zi)    -  _G(V,  xi,   yi-1, zi))
    _x[17] = 0.5*(_G(V, xi+1, yi+1,zi)    -  _G(V,  xi+1, yi-1, zi))
    _x[18] = 0.5*(_G(V, xi,   yi+2,zi)    -  _G(V,  xi,   yi,   zi))
    _x[19] = 0.5*(_G(V, xi+1, yi+2,zi)    -  _G(V,  xi+1, yi,   zi))
    _x[20] = 0.5*(_G(V, xi,   yi+1,zi+1)  -  _G(V,  xi,   yi-1, zi+1))
    _x[21] = 0.5*(_G(V, xi+1, yi+1,zi+1)  -  _G(V,  xi+1, yi-1, zi+1))
    _x[22] = 0.5*(_G(V, xi,   yi+2,zi+1)  -  _G(V,  xi,   yi,   zi+1))
    _x[23] = 0.5*(_G(V, xi+1, yi+2,zi+1)  -  _G(V,  xi+1, yi,   zi+1))
    _x[24] = 0.5*(_G(V, xi,   yi,zi+1)    -  _G(V,  xi,   yi,   zi-1))
    _x[25] = 0.5*(_G(V, xi+1, yi,zi+1)    -  _G(V,  xi+1, yi,   zi-1))
    _x[26] = 0.5*(_G(V, xi,   yi+1,zi+1)  -  _G(V,  xi,   yi+1, zi-1))
    _x[27] = 0.5*(_G(V, xi+1, yi+1,zi+1)  -  _G(V,  xi+1, yi+1, zi-1))
    _x[28] = 0.5*(_G(V, xi,   yi,zi+2)    -  _G(V,  xi,   yi,   zi))
    _x[29] = 0.5*(_G(V, xi+1, yi,zi+2)    -  _G(V,  xi+1, yi,   zi))
    _x[30] = 0.5*(_G(V, xi,   yi+1,zi+2)  -  _G(V,  xi,   yi+1, zi))
    _x[31] = 0.5*(_G(V, xi+1, yi+1,zi+2)  -  _G(V,  xi+1, yi+1, zi))

    _x [32] = 0.25*(_G(V, xi+1, yi+1, zi)   - _G(V, xi-1, yi+1, zi)   - _G(V, xi+1, yi-1, zi)   + _G(V, xi-1, yi-1, zi))
    _x [33] = 0.25*(_G(V, xi+2, yi+1, zi)   - _G(V, xi,   yi+1, zi)   - _G(V, xi+2, yi-1, zi)   + _G(V, xi,   yi-1, zi))
    _x [34] = 0.25*(_G(V, xi+1, yi+2, zi)   - _G(V, xi-1, yi+2, zi)   - _G(V, xi+1, yi,   zi)   + _G(V, xi-1, yi,   zi))
    _x [35] = 0.25*(_G(V, xi+2, yi+2, zi)   - _G(V, xi,   yi+2, zi)   - _G(V, xi+2, yi,   zi)   + _G(V, xi,   yi,   zi))
    _x [36] = 0.25*(_G(V, xi+1, yi+1, zi+1) - _G(V, xi-1, yi+1, zi+1) - _G(V, xi+1, yi-1, zi+1) + _G(V, xi-1, yi-1, zi+1))
    _x [37] = 0.25*(_G(V, xi+2, yi+1, zi+1) - _G(V, xi,   yi+1, zi+1) - _G(V, xi+2, yi-1, zi+1) + _G(V, xi,   yi-1, zi+1))
    _x [38] = 0.25*(_G(V, xi+1, yi+2, zi+1) - _G(V, xi-1, yi+2, zi+1) - _G(V, xi+1, yi,   zi+1) + _G(V, xi-1, yi,   zi+1))
    _x [39] = 0.25*(_G(V, xi+2, yi+2, zi+1) - _G(V, xi,   yi+2, zi+1) - _G(V, xi+2, yi,   zi+1) + _G(V, xi,   yi,   zi+1))
    _x [40] = 0.25*(_G(V, xi+1, yi,   zi+1) - _G(V, xi-1, yi,   zi+1) - _G(V, xi+1, yi,   zi-1) + _G(V, xi-1, yi,   zi-1))
    _x [41] = 0.25*(_G(V, xi+2, yi,   zi+1) - _G(V, xi,   yi,   zi+1) - _G(V, xi+2, yi,   zi-1) + _G(V, xi,   yi,   zi-1))
    _x [42] = 0.25*(_G(V, xi+1, yi+1, zi+1) - _G(V, xi-1, yi+1, zi+1) - _G(V, xi+1, yi+1, zi-1) + _G(V, xi-1, yi+1, zi-1))
    _x [43] = 0.25*(_G(V, xi+2, yi+1, zi+1) - _G(V, xi,   yi+1, zi+1) - _G(V, xi+2, yi+1, zi-1) + _G(V, xi,   yi+1, zi-1))
    _x [44] = 0.25*(_G(V, xi+1, yi,   zi+2) - _G(V, xi-1, yi,   zi+2) - _G(V, xi+1, yi,   zi)   + _G(V, xi-1, yi,   zi))
    _x [45] = 0.25*(_G(V, xi+2, yi,   zi+2) - _G(V, xi,   yi,   zi+2) - _G(V, xi+2, yi,   zi)   + _G(V, xi,   yi,   zi))
    _x [46] = 0.25*(_G(V, xi+1, yi+1, zi+2) - _G(V, xi-1, yi+1, zi+2) - _G(V, xi+1, yi+1, zi)   + _G(V, xi-1, yi+1, zi))
    _x [47] = 0.25*(_G(V, xi+2, yi+1, zi+2) - _G(V, xi,   yi+1, zi+2) - _G(V, xi+2, yi+1, zi)   + _G(V, xi,   yi+1, zi))
    _x [48] = 0.25*(_G(V, xi,   yi+1, zi+1) - _G(V, xi,   yi-1, zi+1) - _G(V, xi,   yi+1, zi-1) + _G(V, xi,   yi-1, zi-1))
    _x [49] = 0.25*(_G(V, xi+1, yi+1, zi+1) - _G(V, xi+1, yi-1, zi+1) - _G(V, xi+1, yi+1, zi-1) + _G(V, xi+1, yi-1, zi-1))
    _x [50] = 0.25*(_G(V, xi,   yi+2, zi+1) - _G(V, xi,   yi,   zi+1) - _G(V, xi,   yi+2, zi-1) + _G(V, xi,   yi,   zi-1))
    _x [51] = 0.25*(_G(V, xi+1, yi+2, zi+1) - _G(V, xi+1, yi,   zi+1) - _G(V, xi+1, yi+2, zi-1) + _G(V, xi+1, yi,   zi-1))
    _x [52] = 0.25*(_G(V, xi,   yi+1, zi+2) - _G(V, xi,   yi-1, zi+2) - _G(V, xi,   yi+1, zi)   + _G(V, xi,   yi-1, zi))
    _x [53] = 0.25*(_G(V, xi+1, yi+1, zi+2) - _G(V, xi+1, yi-1, zi+2) - _G(V, xi+1, yi+1, zi)   + _G(V, xi+1, yi-1, zi))
    _x [54] = 0.25*(_G(V, xi,   yi+2, zi+2) - _G(V, xi,   yi,   zi+2) - _G(V, xi,   yi+2, zi)   + _G(V, xi,   yi,   zi))
    _x [55] = 0.25*(_G(V, xi+1, yi+2, zi+2) - _G(V, xi+1, yi,   zi+2) - _G(V, xi+1, yi+2, zi)   + _G(V, xi+1, yi,   zi))

    _x[56] = 0.125*(_G(V, xi+1, yi+1, zi+1) - _G(V, xi-1, yi+1, zi+1) - _G(V, xi+1, yi-1, zi+1) + _G(V, xi-1, yi-1, zi+1) - _G(V, xi+1, yi+1, zi-1) + _G(V, xi-1,yi+1,zi-1)+_G(V, xi+1,yi-1,zi-1)-_G(V, xi-1,yi-1,zi-1))
    _x[57] = 0.125*(_G(V, xi+2, yi+1, zi+1) - _G(V, xi,   yi+1, zi+1) - _G(V, xi+2, yi-1, zi+1) + _G(V, xi,   yi-1, zi+1) - _G(V, xi+2, yi+1, zi-1) + _G(V, xi,yi+1,zi-1)+_G(V, xi+2,yi-1,zi-1)-_G(V, xi,yi-1,zi-1))
    _x[58] = 0.125*(_G(V, xi+1, yi+2, zi+1) - _G(V, xi-1, yi+2, zi+1) - _G(V, xi+1, yi,   zi+1) + _G(V, xi-1, yi,   zi+1) - _G(V, xi+1, yi+2, zi-1) + _G(V, xi-1,yi+2,zi-1)+_G(V, xi+1,yi,zi-1)-_G(V, xi-1,yi,zi-1))
    _x[59] = 0.125*(_G(V, xi+2, yi+2, zi+1) - _G(V, xi,   yi+2, zi+1) - _G(V, xi+2, yi,   zi+1) + _G(V, xi,   yi,   zi+1) - _G(V, xi+2, yi+2, zi-1) + _G(V, xi,yi+2,zi-1)+_G(V, xi+2,yi,zi-1)-_G(V, xi,yi,zi-1))
    _x[60] = 0.125*(_G(V, xi+1, yi+1, zi+2) - _G(V, xi-1, yi+1, zi+2) - _G(V, xi+1, yi-1, zi+2) + _G(V, xi-1, yi-1, zi+2) - _G(V, xi+1, yi+1, zi)   + _G(V, xi-1,yi+1,zi)+_G(V, xi+1,yi-1,zi)-_G(V, xi-1,yi-1,zi))
    _x[61] = 0.125*(_G(V, xi+2, yi+1, zi+2) - _G(V, xi,   yi+1, zi+2) - _G(V, xi+2, yi-1, zi+2) + _G(V, xi,   yi-1, zi+2) - _G(V, xi+2, yi+1, zi)   + _G(V, xi,yi+1,zi)+_G(V, xi+2,yi-1,zi)-_G(V, xi,yi-1,zi))
    _x[62] = 0.125*(_G(V, xi+1, yi+2, zi+2) - _G(V, xi-1, yi+2, zi+2) - _G(V, xi+1, yi,   zi+2) + _G(V, xi-1, yi,   zi+2) - _G(V, xi+1, yi+2, zi)   + _G(V, xi-1,yi+2,zi)+_G(V, xi+1,yi,zi)-_G(V, xi-1,yi,zi))
    _x[63] = 0.125*(_G(V, xi+2, yi+2, zi+2) - _G(V, xi,   yi+2, zi+2) - _G(V, xi+2, yi,   zi+2) + _G(V, xi,   yi,   zi+2) - _G(V, xi+2, yi+2, zi)   + _G(V, xi,yi+2,zi)+_G(V, xi+2,yi,zi)-_G(V, xi,yi,zi))

    for j in prange(64, nogil=True):
        coef[j] = 0.0
        for i in range(64):
                coef[j] += (temp[j][i] * _x[i])


cdef double tricub_interpolate(image_t[:, :, :] V, double x, double y, double z) nogil:
    # From: Tricubic interpolation in three dimensions. Lekien and Marsden
    cdef double[64] coef
    cdef double result = 0.0
    calc_coef_tricub(V, x, y, z, coef)

    cdef int i, j, k

    cdef int xi = <int>floor(x)
    cdef int yi = <int>floor(y)
    cdef int zi = <int>floor(z)

    for i in range(4):
        for j in range(4):
            for k in range(4):
                result += (coef[i+4*j+16*k] * ((x-xi)**i) * ((y-yi)**j) * ((z-zi)**k))
    # return V[<int>z, <int>y, <int>x]
    # with gil:
        # print result
    return result


cdef double cubicInterpolate(double p[4], double x) noexcept nogil: 
    return p[1] + 0.5 * x*(p[2] - p[0] + x*(2.0*p[0] - 5.0*p[1] + 4.0*p[2] - p[3] + x*(3.0*(p[1] - p[2]) + p[3] - p[0])))


cdef double bicubicInterpolate (double p[4][4], double x, double y) noexcept nogil:
    cdef double arr[4]
    arr[0] = cubicInterpolate(p[0], y)
    arr[1] = cubicInterpolate(p[1], y)
    arr[2] = cubicInterpolate(p[2], y)
    arr[3] = cubicInterpolate(p[3], y)
    return cubicInterpolate(arr, x)


cdef double tricubicInterpolate(image_t[:, :, :] V, double x, double y, double z) noexcept nogil:
    # From http://www.paulinternet.nl/?page=bicubic
    cdef double p[4][4][4]

    cdef int xi = <int>floor(x)
    cdef int yi = <int>floor(y)
    cdef int zi = <int>floor(z)

    cdef int i, j, k

    for i in range(4):
        for j in range(4):
            for k in range(4):
                p[i][j][k] = _G(V, xi + i -1, yi + j -1, zi + k - 1)

    cdef double arr[4]
    arr[0] = bicubicInterpolate(p[0], y-yi, z-zi)
    arr[1] = bicubicInterpolate(p[1], y-yi, z-zi)
    arr[2] = bicubicInterpolate(p[2], y-yi, z-zi)
    arr[3] = bicubicInterpolate(p[3], y-yi, z-zi)
    return cubicInterpolate(arr, x-xi)


def tricub_interpolate_py(image_t[:, :, :] V, double x, double y, double z):
    return tricub_interpolate(V, x, y, z)

def tricub_interpolate2_py(image_t[:, :, :] V, double x, double y, double z):
    return tricubicInterpolate(V, x, y, z)

def trilin_interpolate_py(image_t[:, :, :] V, double x, double y, double z):
    return interpolate(V, x, y, z)
