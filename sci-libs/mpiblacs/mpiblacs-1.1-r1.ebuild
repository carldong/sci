# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=4
inherit eutils toolchain-funcs versionator alternatives-2

DESCRIPTION="Basic Linear Algebra Communication Subprograms with MPI"
HOMEPAGE="http://www.netlib.org/blacs/"
SRC_URI="${HOMEPAGE}/${PN}.tgz
	${HOMEPAGE}/${PN}-patch03.tgz
	test? ( ${HOMEPAGE}/blacstester.tgz )"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="static-libs test"

RDEPEND="virtual/mpi[fortran]
	virtual/blas
	!>sci-libs/scalapack-2"
DEPEND="${RDEPEND}
	dev-util/pkgconfig"

S="${WORKDIR}/BLACS"

make_shared_lib() {
	local libstatic=${1}
	local soname=$(basename "${1%.a}").so.$(get_major_version)
	shift
	einfo "Making ${soname}"
	${LINK:-$(tc-getCC)} ${LDFLAGS}  \
		-shared -Wl,-soname="${soname}" \
		-Wl,--whole-archive "${libstatic}" -Wl,--no-whole-archive \
		"$@" -o $(dirname "${libstatic}")/"${soname}" || die "${soname} failed"
	ln -s "${soname}" $(dirname "${libstatic}")/"${soname%.*}"
}

src_prepare() {
	find . -name Makefile -exec sed -i -e 's:make:$(MAKE):g' '{}' \;

	sed -e "s:\(SHELL\s*=\).*:\1$(type -P sh):" \
		-e "s:\(BTOPdir\s*=\).*:\1${S}:" \
		-e "s:\(BLACSFINIT\s*=\).*:\1\$(BLACSdir)/lib${PN}F77init.a:" \
		-e "s:\(BLACSCINIT\s*=\).*:\1\$(BLACSdir)/lib${PN}Cinit.a:" \
		-e "s:\(BLACSLIB\s*=\).*:\1\$(BLACSdir)/lib${PN}.a:" \
		-e "s:\(MPIINCdir\s*=\).*:\1${EPREFIX}/usr/include:" \
		-e "s:\(MPILIB\s*=\).*:\1:" \
		-e '/SYSINC.*=/d' \
		-e 's:\(INTFACE\s*=\).*:\1-DAdd_:' \
		-e 's:\(TRANSCOMM\s*=\).*:\1-DUseMpi2:' \
		-e "s:\(F77\s*=\).*:\1mpif77:" \
		-e "s:\(F77NO_OPTFLAGS\s*=\).*:\1-O0:" \
		-e "s:\(F77FLAGS\s*=\).*:\1${FFLAGS}:" \
		-e "s:\(F77LOADFLAGS\s*=\).*:\1${LDFLAGS}:" \
		-e "s:\(CC\s*=\).*:\1mpicc:" \
		-e "s:\(CCFLAGS\s*=\).*:\1${CFLAGS}:" \
		-e "s:\(CCLOADFLAGS\s*=\).*:\1${LDFLAGS}:" \
		-e "s:\(ARCH\s*=\).*:\1$(tc-getAR):" \
		-e "s:\(RANLIB\s*=\).*:\1$(tc-getRANLIB):" \
		BMAKES/Bmake.MPI-LINUX > Bmake.inc || die
}

src_compile() {
	emake \
		F77NO_OPTFLAGS="-O0 -fPIC" \
		F77FLAGS="${FFLAGS} -fPIC" \
		CCFLAGS="${CFLAGS} -fPIC" \
		mpi
	cd LIB
	LINK=mpif77 make_shared_lib lib${PN}.a
	LINK=mpicc make_shared_lib lib${PN}Cinit.a -L. -l${PN}
	LINK=mpif77 make_shared_lib lib${PN}F77init.a -L. -l${PN}
	cd "${S}"
	if use static-libs; then
		emake clean -C SRC/MPI && rm -f LIB/*.a
		emake mpi
	fi
}

src_test() {
	emake tester
	cd TESTING/EXE
	local x
	# do not die because we are expecting an abort
	for x in ./x*; do
		mpirun -np 4 $x 2>&1 | tee $x.log
		grep -q "\*\*\*" $x.log && die "$x failed"
	done
}

src_install() {
	pushd LIB
	dolib.so lib*.so*
	use static-libs && dolib.a lib*.a
	cat <<-EOF > ${PN}.pc
		prefix=${EPREFIX}/usr
		libdir=\${prefix}/$(get_libdir)
		includedir=\${prefix}/include
		Name: ${PN}
		Description: ${DESCRIPTION}
		Version: ${PV}
		URL: ${HOMEPAGE}
		Libs: -L\${libdir} -l${PN} -l${PN}Cinit -l${PN}F77init -lm
		Cflags: -I\${includedir}/${PN}
		Requires: blas
	EOF
	insinto /usr/$(get_libdir)/pkgconfig
	doins ${PN}.pc || die
	alternatives_for blacs ${PN} 0 \
		"/usr/$(get_libdir)/pkgconfig/blacs.pc" "${PN}.pc"
	popd

	pushd SRC/MPI
	insinto /usr/include/blacs
	doins Bconfig.h Bdef.h
	popd
}
