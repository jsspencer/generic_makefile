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
SETTINGS_INC = make.inc
else
SETTINGS_INC = make.inc.$(ARCH)
endif
include $(SETTINGS_INC)

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

# Name of source files (if any) which must be recompiled if any other source
# files need to be recompiled.
FORCE_REBUILD_FILES = 

# Allow files to be compiled into a program (MODE = program), or into a library
# (MODE = library) or both (MODE = all).
MODE =

#-----
# Should not need to change anything below here.
#-----

#-----
# Error checking

# Throw an error unless only running help.
ERR = error
ERR_STRING = ERROR
STOP =  # Yes, I do like nicely (and consistently) formatted error and warning messages.
BUILDING = yes
ifndef MAKECMDGOALS
else ifeq ($(filter-out help,$(MAKECMDGOALS)),)
ERR = warning
ERR_STRING = WARNING
STOP = .
BUILDING = no
endif

ifeq ($(PROG_NAME),)
$(call $(ERR), $(ERR_STRING): PROG_NAME is not defined$(STOP))
PROG_NAME = PROG_NAME
endif
ifneq ($(filter-out all program library,$(MODE)),)
$(call $(ERR), $(ERR_STRING): Invalid MODE variable.  MODE must be one of all, program or library.)
MODE = all
endif
ifeq ($(VPATH),)
$(call $(ERR), $(ERR_STRING): VPATH is not defined$(STOP))
endif

#-----
# Type of target

ifeq ($(MAKECMDGOALS),)
__COMPILE_TARGET__ := yes
else
ifneq ($(filter-out help clean cleanall ctags,$(MAKECMDGOALS)),)
__COMPILE_TARGET__ := yes
else
__COMPILE_TARGET__ := no
endif
endif

#-----
# Utility commands

# md5 sum of a file.
md5 = $(firstword $(shell md5sum $1 2> /dev/null))
# Check md5sum (first argument) is the md5sum of a file (second argument).
# Null output if true, returns __FORCE_BUILD__ if false.
# If md5sum doesn't exist (unlikely!) then we err on the side of caution and
# always set __FORCE_BUILD__.
md5_check = $(shell echo $1 $2 | md5sum -c --quiet - > /dev/null 2>/dev/null || echo __FORCE_BUILD__)

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

# Force update of symbolic link if symbolic link doesn't already point to the file.
# (This can occur if we re-run make with a different ARCH file and the binary
# does not need to be updated.)
PROG_RELINK = $(call md5_check, $(call md5, $(BIN_DIR)/$(PROG_VERSION)), $(BIN_DIR)/$(PROG))
LIB_RELINK = $(call md5_check, $(call md5, $(LIB_DIR)/$(LIB_VERSION)), $(LIB_DIR)/$(LIB))

#-----
# Directory structure and setup.

# Directory for objects.
DEST_ROOT = dest
DEST = $(DEST_ROOT)/$(CONFIG)/$(OPT)

# Directory for compiled executables.
BIN_DIR = bin

# Directory for compiled libraries.
LIB_DIR = lib

# Directory for dependency files.
DEPEND_DIR = $(DEST_ROOT)/depend

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

# Function to obtain full path to all objects from source filename(s).
objects_path = $(addprefix $(DEST)/, $(addsuffix .o,$(basename $(notdir $(1)))))

# Full path to all objects.
OBJECTS := $(call objects_path, $(SRCFILES))

# Full path to all objects in library.
ifneq ($(MAIN),)
MAIN_OBJ := $(call objects_path, $(MAIN))
LIB_OBJECTS := $(filter-out $(MAIN_OBJ),$(OBJECTS))
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
# Use CC (CXX) to generate C (C++) dependency files unless CCD (CXXD) is defined.
ifeq ($(CCD),)
CCD = $(CC)
endif
ifeq ($(CXXD),)
CXXD = $(CXX)
endif

#-----
# Compilation macros.

.SUFFIXES:
.SUFFIXES: $(EXTS)

#--- Fortran ---

# Files to be pre-processed then compiled.
$(DEST)/%.o: %.F
ifdef CPP
	$(CPP) $(CPPFLAGS) $< $(@:.o=.f90)
	$(FC) -c $(FFLAGS) $(@:.o=.f90) -o $@ $(F90_MOD_FLAG)$(DEST)
else
	$(FC) $(CPPFLAGS) -c $(FFLAGS) $< -o $@ $(F90_MOD_FLAG)$(DEST)
endif
$(DEST)/%.o: %.F90
ifdef CPP
	$(CPP) $(CPPFLAGS) $< $(@:.o=.f90)
	$(FC) -c $(FFLAGS) $(@:.o=.f90) -o $@ $(F90_MOD_FLAG)$(DEST)
else
	$(FC) $(CPPFLAGS) -c $(FFLAGS) $< -o $@ $(F90_MOD_FLAG)$(DEST)
endif

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
	$(CCD) $(CPPFLAGS) $(INCLUDE) $(CFLAGS) -MM -MT '$$(DEST)/$(@F:.d=.o)' $< -o $@

#--- C++ ---

# All C++ files are preprocessed as part of the compilation.

# object...
$(DEST)/%.o: %.cpp
	$(CXX) $(CPPFLAGS) $(INCLUDE) -c $(CXXFLAGS) $< -o $@

# corresponding dependency...
$(DEPEND_DIR)/%.d: %.cpp
	$(CXXD) $(CPPFLAGS) $(INCLUDE) $(CXXFLAGS) -MM -MT '$$(DEST)/$(@F:.d=.o)' $< -o $@

#-----
# Goals.

.PHONY: clean cleanall new help ctags program library __FORCE_BUILD__

LINK_MACRO = cd $(@D) && ln -s -f $(<F) $(@F)

# Compile program (if desired).
ifneq ($(filter-out library, $(MODE)),)
$(BIN_DIR)/$(PROG): $(BIN_DIR)/$(PROG_VERSION) $(PROG_RELINK)
	$(LINK_MACRO)

$(BIN_DIR)/$(PROG_VERSION): $(OBJECTS) | $(BIN_DIR)
	$(LD) -o $@ $(FFLAGS) $(LDFLAGS) -I $(DEST) $(OBJECTS) $(LIBS)

# shortcut
program: $(BIN_DIR)/$(PROG)
endif

# Compile library (if desired).
ifneq ($(filter-out program, $(MODE)),)
$(LIB_DIR)/$(LIB): $(LIB_DIR)/$(LIB_VERSION) $(LIB_RELINK)
	$(LINK_MACRO)

$(LIB_DIR)/$(LIB_VERSION): $(LIB_OBJECTS) | $(LIB_DIR)
	$(AR) $(ARFLAGS) $@ $^

# shortcut
library: $(BIN_DIR)/$(LIB)
endif

# Create directories.
$(BIN_DIR) $(LIB_DIR) $(DEST) $(DEPEND_DIR):
	mkdir -p $@

# Remove compiled objects and executable.
clean:
	rm -f $(DEST)/*
ifneq ($(filter-out library, $(MODE)),)
	rm -f $(BIN_DIR)/$(PROG_VERSION) $(BIN_DIR)/$(PROG)
else ifneq ($(filter-out program, $(MODE)),)
	rm -f $(LIB_DIR)/$(LIB_VERSION) $(LIB_DIR)/$(LIB)
endif

cleanall:
	rm -rf $(DEPEND_DIR) $(DEST_ROOT)
# don't fail if {BIN,LIB}_DIR isn't empty (but also
# don't remove other files from {BIN,LIB}_DIR which weren't created by
# make).
ifneq ($(filter-out library, $(MODE)),)
	rm -f $(BIN_DIR)/$(PROG_NAME).*.x $(BIN_DIR)/$(PROG)
	rmdir $(BIN_DIR) || true
else ifneq ($(filter-out program, $(MODE)),)
	rm -f $(LIB_DIR)/lib$(PROG_NAME).*.a $(LIB_DIR)/$(LIB)
	rmdir $(LIB_DIR) || true
endif

# Build from scratch.
new: clean $(.DEFAULT_GOAL)

# Generate dependency file.
$(F_DEPEND): $(F_FILES)
	tools/sfmakedepend --file - --silent $^ --objdir \$$\(DEST\) --moddir \$$\(DEST\) > $@

# tag files
# ctags >> etags supplied by emacs
ctags:
	ctags $(SRCFILES)

# null target to force a build
__FORCE_BUILD__: ;

help:
	@echo Usage: make target [ARCH=XXX]
	@echo
	@echo Takes settings from make.inc.XXX if ARCH is set and from make.inc otherwise.
	@echo
	@echo Available targets:
	@echo
ifneq ($(filter-out library, $(MODE)),)
	@echo $(BIN_DIR)/$(PROG) [default]
	@echo -e "\tCompile $(BIN_DIR)/$(PROG_VERSION) and create $(BIN_DIR)/$(PROG) as a symbolic link to it."
	@echo $(BIN_DIR)/$(PROG_VERSION)
	@echo -e "\tCompile the $(BIN_DIR)/$(PROG_VERSION) executable using the settings in $(SETTINGS_INC)."
	@echo program
	@echo -e "\tShortcut for the $(BIN_DIR)/$(PROG) target."
endif
ifneq ($(filter-out program, $(MODE)),)
ifeq ($(filter-out library, $(MODE)),library)
	@echo $(LIB_DIR)/$(LIB) [default]
else
	@echo $(LIB_DIR)/$(LIB)
endif
	@echo -e "\tCompile $(LIB_DIR)/$(LIB_VERSION) and create $(LIB_DIR)/$(LIB) as a symbolic link to it."
	@echo $(LIB_DIR)/$(LIB_VERSION)
	@echo -e "\tCompile the $(LIB_DIR)/$(LIB_VERSION) library using the settings in $(SETTINGS_INC)."
	@echo library
	@echo -e "\tShortcut for the $(LIB_DIR)/$(LIB) target."
endif
	@echo ctags
	@echo -e "\tRun ctags on all source files."
	@echo clean
	@echo -e "\tDelete all object files, binaries and libraries created using $(SETTINGS_INC)."
	@echo cleanall
	@echo -e "\tDelete all object files, dependency files, binaries and libraries created by all configurations."
	@echo new
	@echo -e "\tRun the clean and then $(BIN_DIR)/$(PROG) targets."

#-----
# Dependencies.

# Include dependency file.
# $(*_DEPEND) will be generated if it doesn't exist.
ifeq ($(__COMPILE_TARGET__),yes)
# Create dependency directory if required.
$(F_DEPEND) $(C_DEPEND): | $(DEPEND_DIR)
ifneq ($(F_DEPEND),)
include $(F_DEPEND)
endif
ifneq ($(C_DEPEND),)
include $(C_DEPEND)
endif
endif

# Other dependencies.
# Rebuild objects from files given in FORCE_REBUILD_FILES if any other source file has changed.
ifneq ($(FORCE_REBUILD_FILES),)
FORCE_REBUILD_OBJECTS := $(call objects_path, $(FORCE_REBUILD_FILES))
$(FORCE_REBUILD_OBJECTS): $(SRCFILES)
endif
# Create object directory if required before compiling anything.
$(OBJECTS): | $(DEST)
