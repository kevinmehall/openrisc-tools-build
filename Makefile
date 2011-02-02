#!/usr/bin/make -f

PREFIX:=${PWD}/toolchain-out
TARGET:=or32-linux
SYSROOT:=${PREFIX}/${TARGET}/sys-root

PATH:=${PREFIX}/bin:${PATH}


STAMPS:=${PWD}/stamps


MAKE_TARGETS:=binutils gcc uClibc linux-headers gcc-bootstrap

all: uClibc

.PHONY: build-linux-headers
build-linux-headers:
	cd linux \
	 && make ARCH=openrisc INSTALL_HDR_PATH=${SYSROOT}/usr headers_install

.PHONY: build-binutils
build-binutils:
	mkdir -p binutils-build
	cd binutils-build \
	 && ../binutils/configure --prefix=${PREFIX} --target=${TARGET} --with-sysroot \
	 && make \
	 && make install

.PHONY: build-gcc-bootstrap
build-gcc-bootstrap: binutils
	mkdir -p gcc-bootstrap-build
	cd gcc-bootstrap-build \
	 && ../gcc/configure --target=${TARGET} --prefix=${PREFIX} \
	 --disable-libssp --srcdir=../gcc --enable-languages=c \
	 --without-headers --enable-threads=single --disable-libgomp \
	 --disable-libmudflap \
	 && make \
	 && make install

.PHONY: build-uClibc
build-uClibc: gcc-bootstrap linux-headers
	cd uClibc && make ARCH=or32 defconfig
	cd uClibc \
	 && make PREFIX=${SYSROOT} SYSROOT=${SYSROOT} CROSS_COMPILER_PREFIX=${TARGET}- \
	 && make PREFIX=${SYSROOT} SYSROOT=${SYSROOT} CROSS_COMPILER_PREFIX=${TARGET}- install \
	 && touch ${STAMPS}/uClibc-installed

.PHONY: build-gcc
build-gcc:
	mkdir -p gcc-build
	cd gcc-build \
	 && ../gcc/configure --target=${TARGET} --prefix=${PREFIX} \
	 --disable-libssp --srcdir=../gcc --enable-languages=c      \
	 --enable-threads=posix --disable-libgomp --disable-libmudflap  \
	 --with-sysroot=${SYSROOT} \
	 && make \
	 && make install

.PHONY: clean
clean:
	rm -rf *-build


test:
	export PATH=/home/jonas/opencores/toolchain/bin:${PATH} 
	which or32-linux-gcc
	mkdir x
	 cd x \
	 && which or32-linux-gcc \
	 && touch hi \
	 && echo hello > hi
	
${STAMPS}/%: build-%
	touch $@

.PHONY: ${MAKE_TARGETS}
$(filter %,${MAKE_TARGETS}): %: ${STAMPS}/%

#.PHONY: %
#%: ${STAMPS}/$<
#binutils: ${STAMPS}/binutils
#gcc-bootstrap: ${STAMPS}/gcc-bootstrap
#linux-headers: ${STAMPS}/linux-headers
#uClibc: ${STAMPS}/uClibc
