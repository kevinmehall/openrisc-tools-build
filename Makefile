#!/usr/bin/make -f

PREFIX?=${PWD}/toolchain-out
TARGET:=or32-linux
SYSROOT:=${PREFIX}/${TARGET}/sys-root

# Only want to build subproject makefiles in parallel, not targets here
PARALLEL?=3

PATH:=${PREFIX}/bin:${PATH}


STAMPS:=${PWD}/stamps
LOGS:=${PWD}/logs

MAKE_TARGETS:=binutils gcc uClibc linux-headers gcc-bootstrap

all: gcc

${STAMPS}/build-sys-init:
	@mkdir -p ${STAMPS} \
	 && mkdir -p ${LOGS} \
	 && touch $@

${STAMPS}/install-linux-headers: | ${STAMPS}/build-sys-init
	@echo Installing: linux-headers
	@cd linux \
	 && (${MAKE} ARCH=openrisc INSTALL_HDR_PATH=${SYSROOT}/usr headers_install >${LOGS}/install-linux-headers.log 2>&1 \
	 && touch $@) || cat ${LOGS}/install-linux-headers.log

CONFIGURE_binutils := --prefix=${PREFIX} --target=${TARGET} --with-sysroot --enable-werror=no

BUILDDEPS_gcc-bootstrap := binutils ${STAMPS}/gcc-bootstrap-src-link
CONFIGURE_gcc-bootstrap := --target=${TARGET} --prefix=${PREFIX} \
         --disable-libssp --srcdir=../gcc --enable-languages=c \
         --without-headers --enable-threads=single --disable-libgomp \
         --disable-libmudflap

${STAMPS}/gcc-bootstrap-src-link: ${STAMPS}/build-sys-init
	@ln -sf -T gcc gcc-bootstrap \
	 && touch $@

BUILDDEPS_uClibc := gcc-bootstrap linux-headers
MAKE_uClibc := PREFIX=${SYSROOT} SYSROOT=${SYSROOT} CROSS_COMPILER_PREFIX=${TARGET}-
INSTALL_uClibc := ${MAKE_uClibc}

${STAMPS}/install-uClibc: ${BUILDDEPS_uClibc}
	@cd uClibc && ${MAKE} ARCH=or32 defconfig
	@cd uClibc \
	 && ${MAKE} ${MAKE_uClibc} \
	 && ${MAKE} ${INSTALL_uClibc} install \
	 && touch $@ \

BUILDDEPS_gcc := uClibc
CONFIGURE_gcc := --target=${TARGET} --prefix=${PREFIX} \
         --disable-libssp --srcdir=../gcc --enable-languages=c,c++      \
         --enable-threads=posix --disable-libgomp --disable-libmudflap  \
         --disable-shared --with-sysroot=${SYSROOT}

.PHONY: clean
clean:
	rm -rf *-build
	rm -rf logs
	rm -rf stamps
	
#.PHONY: ${MAKE_TARGETS}
$(filter %,${MAKE_TARGETS}): %: ${STAMPS}/install-%

$(patsubst %,install-%,${MAKE_TARGETS}): install-%: ${STAMPS}/install-%
$(patsubst %,reinstall-%,${MAKE_TARGETS}): reinstall-%: ${STAMPS}/install-% | rebuild-%

$(patsubst %,configure-%,${MAKE_TARGETS}): configure-%: ${STAMPS}/configure-%
$(patsubst %,build-%,${MAKE_TARGETS}): build-%: ${STAMPS}/build-%

$(patsubst %,rebuild-%,${MAKE_TARGETS}): rebuild-%: ${STAMPS}/build-%
	rm -f ${STAMPS}/install-$*

$(patsubst %,clean-%,${MAKE_TARGETS}): clean-%:
	rm -rf $*-build

.SECONDEXPANSION:
${STAMPS}/configure-%: $${BUILDDEPS_%} | ${STAMPS}/build-sys-init
	@echo Configuring: $*
	@mkdir -p $*-build
	@cd $*-build \
	 && (../$*/configure ${CONFIGURE_$*} >${LOGS}/configure-$*.log 2>&1 \
	 && touch $@) || (cat ${LOGS}/configure-$*.log; exit 1)

${STAMPS}/build-%: ${STAMPS}/configure-%
	@echo Building: $*
	@cd $*-build \
	 && (${MAKE} -j$(PARALLEL) ${MAKE_$*} >${LOGS}/build-$*.log 2>&1 \
	 && touch $@) || (cat ${LOGS}/build-$*.log; exit 1)

${STAMPS}/install-%: ${STAMPS}/build-%
	@echo Installing: $*
	@cd $*-build \
	 && (${MAKE} install ${INSTALL_$*} >${LOGS}/install-$*.log 2>&1 \
	 && touch $@) || (cat ${LOGS}/install-$*.log; exit 1)


#.PHONY: %
#%: ${STAMPS}/$<
#binutils: ${STAMPS}/binutils
#gcc-bootstrap: ${STAMPS}/gcc-bootstrap
#linux-headers: ${STAMPS}/linux-headers
#uClibc: ${STAMPS}/uClibc
