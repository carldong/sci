# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5

AUTOTOOLS_AUTORECONF=true

inherit autotools-utils

ELMER_ROOT="elmerfem"
MY_PN=${PN/elmer-/}

DESCRIPTION="Finite element programs, libraries, and visualization tools - elmer I/O library"
HOMEPAGE="http://www.csc.fi/english/pages/elmer"
SRC_URI="http://elmerfem.svn.sourceforge.net/viewvc/${ELMER_ROOT}/release/${PV}/${MY_PN}/?view=tar -> ${P}.tar.gz"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="debug static-libs"

S="${WORKDIR}/eio"

PATCHES=( "${FILESDIR}"/${P}-shared.patch )

src_configure() {
	local myeconfargs=(
		--enable-shared
		$(use_with debug)
	)
	autotools-utils_src_configure
}
