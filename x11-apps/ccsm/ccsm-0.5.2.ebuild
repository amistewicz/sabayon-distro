# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

DESCRIPTION="Compizconfig Settings Manager"
HOMEPAGE="http://opencompositing.org"
SRC_URI="http://releases.compiz-fusion.org/${PV}/${P}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""
RESTRICT="mirror"

DEPEND="~dev-python/compizconfig-python-${PV}
	>=dev-python/pygtk-2.10"

S="${WORKDIR}/${P}"

src_compile() {
	cd ${S}
	./setup.py build --prefix=/usr
}

src_install() {
	./setup.py install --root=${D} --prefix=/usr
}

pkg_postinst() {
	ewarn "DO NOT report bugs to Gentoo's bugzilla"
	einfo "Please report all bugs at http://forums.gentoo-xeffects.org/"
	einfo "Thank you on behalf of the Gentoo Xeffects team"
}
