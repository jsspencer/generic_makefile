# A generic makefile for Fortran, C and C++ code.
#
# http://github.com/jsspencer/generic_makefile
#
# copyright (c) 2012, James Spencer.
#
# MIT license:
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

SHELL=/bin/bash # For our sanity!

#-----
# Include arch file.

ifeq ($(ARCH),)
include make.inc
SETTINGS_INC = make.inc
else
include make.inc.$(ARCH)
SETTINGS_INC = make.inc.$(ARCH)
endif

#-----
# Configuration

# Program name (stem of binary and library).
PROG_NAME = 

# Colon-separated list of directories containing source files.
# Can be relative to the working directory.  Use . or $(PWD) to indicate the
# working directory.
VPATH = 

# Name of source file (if any) containing the entry-point to the program (e.g.
# main function in C or C++ or the file containing the program procedure in
# Fortran).  Used only to generate a library object containing all other
# procedures, if desired.
MAIN = 

#-----
# Should not need to change anything below here.
#-----

#-----
# Program

# A source file *must* contain a program entry (e.g.  main() or equivalent
# procedure) in order to create a binary.

# Specific version of binary.
PROG_VERSION = $(PROG_NAME).$(CONFIG).$(OPT).x

# Symbolic link which points to $(PROG_VERSION).
PROG = $(PROG_NAME).x

# MAIN *must* be defined *or* no source files contain a program entry (e.g.
# main() or equivalent procedure) in order to create a library.

# Specific version of library.
LIB_VERSION = lib$(PROG_NAME).$(CONFIG).$(OPT).a

# Symbolic link which points to $(LIB_VERSION).
LIB = lib$(PROG_NAME).a

#-----
# Directory structure and setup.

# Directory for objects.
DEST_ROOT = dest
DEST = $(DEST_ROOT)/$(CONFIG)/$(OPT)

# Directory for compiled executables and libraries.
EXE = bin

# Directory for dependency files.
DEPEND_DIR = $(DEST_ROOT)/depend

# We put compiled objects and modules in $(DEST).  If it doesn't exist, create it.
make_dest := $(shell test -e $(DEST) || mkdir -p $(DEST))
# We put the compiled executable in $(EXE).  If it doesn't exist, then create it.
make_exe := $(shell test -e $(EXE) || mkdir -p $(EXE))
# We put the compiled executable in $(DEPEND_DIR).  If it doesn't exist, then create it.
make_depend := $(shell test -e $(DEPEND_DIR) || mkdir -p $(DEPEND_DIR))

#-----
# Find source files and resultant object files.

# Source extensions.
CEXTS = .c .cpp
FEXTS = .f .F .f90 .F90
EXTS = $(FEXTS) $(CEXTS)

# Space separated list of source directories.
SRCDIRS := $(subst :, ,$(VPATH))

# header files are in source directories: must provide to the C compilers
INCLUDE = $(addprefix -I ,$(SRCDIRS))

# Source filenames.
find_files = $(foreach ext,$(EXTS), $(wildcard $(dir)/*$(ext)))
SRCFILES := $(foreach dir,$(SRCDIRS),$(find_files))

# Objects (strip path and replace extension of source files with .o).
OBJ := $(addsuffix .o,$(basename $(notdir $(SRCFILES))))

# Full path to all objects.
OBJECTS := $(addprefix $(DEST)/, $(OBJ))

# Full path to all objects in library.
ifneq ($(MAIN),)
MAIN_OBJ := $(addsuffix .o,$(basename $(notdir $(MAIN))))
LIB_OBJECTS := $(addprefix $(DEST)/, $(filter-out $(MAIN_OBJ),$(OBJ)))
else
LIB_OBJECTS := $(OBJECTS)
endif

#-----
# Dependency files.

# Fortran (all in one file)
F_FILES = $(filter $(addprefix %,$(FEXTS)), $(SRCFILES))
ifeq ($(F_FILES),)
# leave blank to match the analagous behaviour of C_DEPEND.
F_DEPEND =
else
F_DEPEND = $(DEPEND_DIR)/fortran.d
endif

# C/C++ (one dependency file per source file)
C_FILES = $(filter $(addprefix %,$(CEXTS)), $(SRCFILES))
C_DEPEND = $(addprefix $(DEPEND_DIR)/, $(addsuffix .d, $(basename $(notdir $(C_FILES)))))

#-----
# Compilation macros.

.SUFFIXES:
.SUFFIXES: $(EXTS)

#--- Fortran ---

# Files to be pre-processed then compiled.
$(DEST)/%.o: %.F
	$(FC) $(CPPFLAGS) -c $(FFLAGS) $< -o $@ $(F90_MOD_FLAG)$(DEST)
$(DEST)/%.o: %.F90
	$(FC) $(CPPFLAGS) -c $(FFLAGS) $< -o $@ $(F90_MOD_FLAG)$(DEST)

# Files to compiled directly.
$(DEST)/%.o: %.f
	$(FC) -c $(FFLAGS) $< -o $@ $(F90_MOD_FLAG)$(DEST)
$(DEST)/%.o: %.f90
	$(FC) -c $(FFLAGS) $< -o $@ $(F90_MOD_FLAG)$(DEST)

#--- C ---

# All C files are preprocessed as part of the compilation.

# object...
$(DEST)/%.o: %.c
	$(CC) $(CPPFLAGS) $(INCLUDE) -c $(CFLAGS) $< -o $@

# corresponding dependency...
$(DEPEND_DIR)/%.d: %.c
	$(CC) $(INCLUDE) $(CFLAGS) -MM -MT $(@:.d=.o) $< -o $@

#--- C++ ---

# All C++ files are preprocessed as part of the compilation.

# object...
$(DEST)/%.o: %.cpp
	$(CXX) $(CPPFLAGS) $(INCLUDE) -c $(CXXFLAGS) $< -o $@

# corresponding dependency...
$(DEPEND_DIR)/%.d: %.cpp
	$(CC) $(INCLUDE) $(CXXFLAGS) -MM -MT $(@:.d=.o) $< -o $@

#-----
# Goals.

.PHONY: clean cleanall new help ctags program library

# Compile program.
$(EXE)/$(PROG): $(EXE)/$(PROG_VERSION)
	cd $(EXE) && ln -s -f $(notdir $<) $(notdir $@)

$(EXE)/$(PROG_VERSION): $(OBJECTS)
	$(LD) -o $@ $(FFLAGS) $(LDFLAGS) -I $(DEST) $(OBJECTS) $(LIBS)

# Compile library.
$(EXE)/$(LIB): $(EXE)/$(LIB_VERSION)
	cd $(EXE) && ln -s -f $(notdir $<) $(notdir $@)

$(EXE)/$(LIB_VERSION): $(LIB_OBJECTS)
	$(AR) $(ARFLAGS) $@ $^

# Remove compiled objects and executable.
clean:
	rm -f $(DEST)/* $(EXE)/$(PROG_VERSION) $(EXE)/$(LIB_VERSION)

cleanall:
	rm -rf $(DEST_ROOT) $(EXE)

# Build from scratch.
new: clean $(EXE)/$(PROG)

# Generate dependency file.
$(F_DEPEND): $(F_FILES)
	tools/sfmakedepend --file - --silent $^ --objdir \$$\(DEST\) --moddir \$$\(DEST\) > $@

# tag files
# ctags >> etags supplied by emacs
ctags:
	ctags $(SRCFILES)

# shortcuts
program: $(EXE)/$(PROG)
library: $(EXE)/$(LIB)

help:
	@echo Usage: make target [ARCH=XXX]
	@echo
	@echo Takes settings from make.inc.XXX if ARCH is set and from make.inc otherwise.
	@echo
	@echo Available targets:
	@echo
	@echo $(EXE)/$(PROG)
	@echo -e "\tCompile $(EXE)/$(PROG_VERSION) and create $(EXE)/$(PROG) as a symbolic link to it."
	@echo $(EXE)/$(PROG_VERSION)
	@echo -e "\tCompile the $(EXE)/$(PROG_VERSION) executable using the settings in $(SETTINGS_INC)."
	@echo $(EXE)/$(LIB)
	@echo -e "\tCompile $(EXE)/$(LIB_VERSION) and create $(EXE)/$(LIB) as a symbolic link to it."
	@echo $(EXE)/$(LIB_VERSION)
	@echo -e "\tCompile the $(EXE)/$(LIB_VERSION) library using the settings in $(SETTINGS_INC)."
	@echo program
	@echo -e "\tShortcut for the $(EXE)/$(PROG) target."
	@echo library
	@echo -e "\tShortcut for the $(EXE)/$(LIB) target."
	@echo ctags
	@echo -e "\tRun ctags on all source files."
	@echo clean
	@echo -e "\tDelete all object files, binaries and libraries created using $(SETTINGS_INC)."
	@echo cleanall
	@echo -e "\tDelete all object files, dependency files, binaries and libraries created by all configurations."

#-----
# Include dependency file.

# $(*_DEPEND) will be generated if it doesn't exist.
ifneq ($(F_DEPEND),)
include $(F_DEPEND)
endif
ifneq ($(C_DEPEND),)
include $(C_DEPEND)
endif
