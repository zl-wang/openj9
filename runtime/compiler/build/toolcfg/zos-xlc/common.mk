# Copyright IBM Corp. and others 2000
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which accompanies this
# distribution and is available at https://www.eclipse.org/legal/epl-2.0/
# or the Apache License, Version 2.0 which accompanies this distribution and
# is available at https://www.apache.org/licenses/LICENSE-2.0.
#
# This Source Code may also be made available under the following
# Secondary Licenses when the conditions for such availability set
# forth in the Eclipse Public License, v. 2.0 are satisfied: GNU
# General Public License, version 2 with the GNU Classpath
# Exception [1] and GNU General Public License, version 2 with the
# OpenJDK Assembly Exception [2].
#
# [1] https://www.gnu.org/software/classpath/license.html
# [2] https://openjdk.org/legal/assembly-exception.html
#
# SPDX-License-Identifier: EPL-2.0 OR Apache-2.0 OR GPL-2.0-only WITH Classpath-exception-2.0 OR GPL-2.0-only WITH OpenJDK-assembly-exception-1.0

#
# Explicitly set shell
#
SHELL=/bin/sh

#
# These are the prefixes and suffixes that all GNU tools use for things
#
OBJSUFF=.o
ARSUFF=.a
SOSUFF=.so
EXESUFF=
LIBPREFIX=lib
DEPSUFF=.depend.mk
ifeq ($(VERSION_MAJOR),8)
    ARCHLEVEL=8
    TGTLEVEL=zOSV1R13
    TUNELEVEL?=10
else
    ARCHLEVEL=10
    TGTLEVEL=zOSV2R3
    TUNELEVEL?=12
endif

#
# Paths for default programs on the platform
# Most rules will use these default programs, but they can be overwritten individually if,
# for example, you want to compile .spp files with a different C++ compiler than you use
# to compile .cpp files
#

# Use default AR=ar
# Use default AS=as
M4?=m4
PERL?=perl
ifeq (default,$(origin CC))
    CC=xlc
endif
ifeq (default,$(origin CXX))
    CXX=xlC
endif

#
# First setup C and C++ compilers.
#
#     Note: "CX" means both C and C++
#
C_CMD?=$(CC)
CXX_CMD?=$(CXX)

CX_DEFINES+=\
    $(PRODUCT_DEFINES) \
    $(HOST_DEFINES) \
    $(TARGET_DEFINES) \
    J9ZOS390 \
    LONGLONG \
    _ALL_SOURCE \
    _XOPEN_SOURCE_EXTENDED \
    _POSIX_SOURCE \
    _OPEN_THREADS=2 \
    _ISOC99_SOURCE \
    __STDC_LIMIT_MACROS \
    J9VM_TIERED_CODE_CACHE \
    MAXMOVE \
    COMPRESS_AOT_DATA \
    SUPPORTS_THREAD_LOCAL

CX_FLAGS+=\
    -qlanglvl=extended0x \
    -qhaltonmsg=CCN6102 \
    -Wc,rostring \
    -Wc,"enum(4)" \
    -Wc,xplink \
    -Wc,NOANSIALIAS \
    -Wa,asa,goff,xplink \
    -Wc,DLL,EXPORTALL \
    -Wa,DLL \
    -Wc,"FLOAT(IEEE,FOLD,AFP)" \
    -Wc,"ARCH($(ARCHLEVEL))" \
    -Wc,"TUNE($(TUNELEVEL))" \
    -Wc,"TARGET($(TGTLEVEL))"

# Now we get to do this awesome thing because of EBCDIC
PRODUCT_INCLUDES:=\
    $(J9SRC)/zos_zlib/hzc/include \
    /usr/lpp/hzc/include \
    $(PRODUCT_INCLUDES)

CX_FLAGS+=\
    -qnosearch \
    $(patsubst %,-I%,$(PRODUCT_INCLUDES)) \
    -DIBM_ATOE \
    -D_AE_BIMODAL \
    -Wc,"convlit(ISO8859-1)" \
    -qsearch=$(J9SRC)/a2e/headers \
    -qsearch=$(J9SRC)/zos_zlib/hzc/include \
    -qsearch=/usr/lpp/hzc/include \
    -qsearch=/usr/include \
    -qsearch=$(A2E_INCLUDE_PATH)

CXX_FLAGS+=\
    -+ \
    -Wc,"SUPPRESS(CCN6281,CCN6090)" \
    -Wc,"TMPLPARSE(NO)" \
    -Wc,EXH

CX_DEFINES_DEBUG+=DEBUG
CX_FLAGS_DEBUG+=-g

CX_DEFAULTOPT=-O3
CX_OPTFLAG?=$(CX_DEFAULTOPT)
CX_FLAGS_PROD+=$(CX_OPTFLAG) -Wc,"INLINE(auto,noreport,600,5000)"

ifeq ($(HOST_BITS),64)
    CX_FLAGS+=-Wc,lp64
endif

#
# TODO - What is this actually for?
#        Does anyone use it for anything?
#
ifeq ($(ASMLIST),1)
    CX_FLAGS+=-qoffset -qlist=$@.asmlist
endif

ifeq ($(BUILD_CONFIG),debug)
    CX_DEFINES+=$(CX_DEFINES_DEBUG)
    CX_FLAGS+=$(CX_FLAGS_DEBUG)
endif

ifeq ($(BUILD_CONFIG),prod)
    CX_DEFINES+=$(CX_DEFINES_PROD)
    CX_FLAGS+=$(CX_FLAGS_PROD)
endif

C_INCLUDES=
C_DEFINES+=$(CX_DEFINES) $(CX_DEFINES_EXTRA) $(C_DEFINES_EXTRA)
C_FLAGS+=$(CX_FLAGS) $(CX_FLAGS_EXTRA) $(C_FLAGS_EXTRA)

CXX_INCLUDES=
CXX_DEFINES+=$(CX_DEFINES) $(CX_DEFINES_EXTRA) $(CXX_DEFINES_EXTRA)
CXX_FLAGS+=$(CX_FLAGS) $(CX_FLAGS_EXTRA) $(CXX_FLAGS_EXTRA)

#
# Now setup the z/OS Assembler (which uses the compiler driver)
#
S_CMD?=$(CC)

S_FLAGS+=-Wa,asa,goff -Wa,xplink

S_INCLUDES=$(PRODUCT_INCLUDES)

ifeq ($(BUILD_CONFIG),debug)
    S_FLAGS+=$(S_FLAGS_DEBUG)
endif

ifeq ($(BUILD_CONFIG),prod)
    S_FLAGS+=$(S_FLAGS_PROD)
endif

S_FLAGS+=$(S_FLAGS_EXTRA)

#
# Now we setup M4 to preprocess Z assembly files
#
M4_CMD?=$(M4)

M4_INCLUDES=$(PRODUCT_INCLUDES)
M4_DEFINES+=\
    $(HOST_DEFINES) \
    $(TARGET_DEFINES) \
    J9ZOS390

ifeq ($(HOST_BITS),64)
    M4_DEFINES+=TR_64Bit
endif

ifeq ($(BUILD_CONFIG),debug)
    M4_FLAGS+=$(M4_FLAGS_DEBUG)
endif

ifeq ($(BUILD_CONFIG),prod)
    M4_FLAGS+=$(M4_FLAGS_PROD)
endif

M4_FLAGS+=$(M4_FLAGS_EXTRA)

#
# Now the Z archiver
#
AR_CMD?=$(AR)

#
# Finally setup the linker
#
SOLINK_CMD?=$(CXX)

SOLINK_FLAGS+=-g -Wl,xplink,dll,map,list,compat=$(TGTLEVEL)
SOLINK_LIBPATH+=$(J9SRC) \
                $(J9SRC)/lib \
                $(J9SRC)/zos_zlib/hzc/lib \
                /usr/lpp/hzc/lib
SOLINK_SLINK+=$(PRODUCT_SLINK) \
              zz
SOLINK_EXTRA_ARGS+=\
    $(J9SRC)/lib/libj9a2e.x \
    $(J9SRC)/lib/libj9thr$(J9_VERSION).x \
    $(J9SRC)/lib/libj9hookable$(J9_VERSION).x \


ifeq ($(HOST_BITS),64)
    SOLINK_FLAGS+=-Wl,lp64
endif

ifeq ($(BUILD_CONFIG),debug)
    SOLINK_FLAGS+=$(SOLINK_FLAGS_DEBUG)
endif

ifeq ($(BUILD_CONFIG),prod)
    SOLINK_FLAGS+=$(SOLINK_FLAGS_PROD)
endif

SOLINK_FLAGS+=$(SOLINK_FLAGS_EXTRA)
