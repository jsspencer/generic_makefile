# Example make.inc file.  Not all options need to be set.

#-----
# Config info.

# Used to create a configuration-level and optimisation-level specific
# directory in which compiled objects are placed and to uniquely name binaries.

CONFIG = gnu
OPT = optimised

#-----
# Compiler configuration.

# Pre-processing flags
# Used for *.F, *.F90, *.c and *.cpp files.
CPPFLAGS =

# --- Fortran ---
# compiler
FC = gfortran
# compiler flags
FFLAGS = -O3
# flag to specify directory to put compiled .mod files (e.g. -module for ifort, -J for gfortran)
F90_MOD_FLAG = -J

# --- C ---
# compiler
CC = gcc
# compiler flags
CFLAGS = -O3

# --- C++ ---
# compiler
CXX = g++
# compiler flags
CXXFLAGS = -O3

# --- Linker ---
# linker
LD = gfortran
# linker flags
LDFLAGS = 
# additional libraries to link to
LIBS = -llapack -lblas -lstdc++

# --- Archiver ---
# archive program (usually ar)
AR = ar
# archive flags (usually -rcs)
ARFLAGS = -rcs
