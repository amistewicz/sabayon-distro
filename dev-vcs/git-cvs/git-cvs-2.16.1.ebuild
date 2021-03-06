# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

GENTOO_DEPEND_ON_PERL=no

PYTHON_COMPAT=( python2_7 )
if [[ ${PV} == *9999 ]]; then
	SCM="git-r3"
	EGIT_REPO_URI="git://git.kernel.org/pub/scm/git/git.git"
	# Please ensure that all _four_ 9999 ebuilds get updated; they track the 4 upstream branches.
	# See https://git-scm.com/docs/gitworkflows#_graduation
	# In order of stability:
	# 9999-r0: maint
	# 9999-r1: master
	# 9999-r2: next
	# 9999-r3: pu
	case "${PVR}" in
		9999) EGIT_BRANCH=maint ;;
		9999-r1) EGIT_BRANCH=master ;;
		9999-r2) EGIT_BRANCH=next;;
		9999-r3) EGIT_BRANCH=pu ;;
	esac
fi

inherit toolchain-funcs eutils multilib python-single-r1 ${SCM}

MY_PV="${PV/_rc/.rc}"
MY_PN="${PN/-cvs}"
MY_P="${MY_PN}-${MY_PV}"

DOC_VER=${MY_PV}

DESCRIPTION="CVS module for git"
HOMEPAGE="http://www.git-scm.com/"
if [[ ${PV} != *9999 ]]; then
	SRC_URI_SUFFIX="xz"
	SRC_URI_KORG="mirror://kernel/software/scm/git"
	[[ "${PV/rc}" != "${PV}" ]] && SRC_URI_KORG+='/testing'
	SRC_URI="${SRC_URI_KORG}/${MY_P}.tar.${SRC_URI_SUFFIX}
			${SRC_URI_KORG}/${MY_PN}-manpages-${DOC_VER}.tar.${SRC_URI_SUFFIX}
			doc? (
			${SRC_URI_KORG}/${MY_PN}-htmldocs-${DOC_VER}.tar.${SRC_URI_SUFFIX}
			)"
	[[ "${PV}" = *_rc* ]] || \
	KEYWORDS="~amd64 ~x86"
fi

LICENSE="GPL-2"
SLOT="0"
IUSE="doc"

RDEPEND="~dev-vcs/git-${PV}[-cvs,perl]
	dev-perl/Error
	dev-perl/Net-SMTP-SSL
	dev-perl/Authen-SASL
	>=dev-vcs/cvsps-2.1:0 dev-perl/DBI dev-perl/DBD-SQLite
	${PYTHON_DEPS}"
DEPEND="dev-lang/perl:=[-build(-)]
	doc? (
		app-text/asciidoc
		app-text/docbook2X
		sys-apps/texinfo
		app-text/xmlto
	)"

# Live ebuild builds man pages and HTML docs, additionally
if [[ ${PV} == *9999 ]]; then
	DEPEND="${DEPEND}
		app-text/asciidoc"
fi

S="${WORKDIR}/${MY_P}"

REQUIRED_USE="
	${PYTHON_REQUIRED_USE}
"

PATCHES=(
	# bug #350330 - automagic CVS when we don't want it is bad.
	"${FILESDIR}"/git-2.12.0-optional-cvs.patch

	# install mediawiki perl modules also in vendor_dir
	# hack, needs better upstream solution
	"${FILESDIR}"/git-1.8.5-mw-vendor.patch

	"${FILESDIR}"/git-2.2.0-svn-fe-linking.patch

	# Bug #493306, where FreeBSD 10.x merged libiconv into its libc.
	"${FILESDIR}"/git-2.5.1-freebsd-10.x-no-iconv.patch
)

# This is needed because for some obscure reasons future calls to make don't
# pick up these exports if we export them in src_unpack()
exportmakeopts() {
	local myopts

	# broken assumptions, because of static build system ...
	myopts+=" NO_FINK=YesPlease NO_DARWIN_PORTS=YesPlease"
	myopts+=" INSTALL=install TAR=tar"
	myopts+=" SHELL_PATH=${EPREFIX}/bin/sh"
	myopts+=" SANE_TOOL_PATH="
	myopts+=" OLD_ICONV="
	myopts+=" NO_EXTERNAL_GREP="

	# split ebuild: avoid collisions with dev-vcs/git's .mo files
	myopts+=" NO_GETTEXT=YesPlease"

	# can't define this to null, since the entire makefile depends on it
	sed -i -e '/\/usr\/local/s/BASIC_/#BASIC_/' Makefile

	myopts+=" INSTALLDIRS=vendor"
	myopts+=" NO_SVN_TESTS=YesPlease"
	grep -q getdelim "${ROOT}"/usr/include/stdio.h && \
		myopts+=" HAVE_GETDELIM=1"

	has_version '>=app-text/asciidoc-8.0' \
		&& myopts+=" ASCIIDOC8=YesPlease"
	myopts+=" ASCIIDOC_NO_ROFF=YesPlease"

	# Bug 290465:
	# builtin-fetch-pack.c:816: error: 'struct stat' has no member named 'st_mtim'
	[[ "${CHOST}" == *-uclibc* ]] && \
		myopts+=" NO_NSEC=YesPlease"

	export MY_MAKEOPTS="${myopts}"
}

src_unpack() {
	if [[ ${PV} != *9999 ]]; then
		unpack ${MY_P}.tar.${SRC_URI_SUFFIX}
		cd "${S}"
		unpack ${MY_PN}-manpages-${DOC_VER}.tar.${SRC_URI_SUFFIX}
		use doc && \
			cd "${S}"/Documentation && \
			unpack ${MY_PN}-htmldocs-${DOC_VER}.tar.${SRC_URI_SUFFIX}
		cd "${S}"
	else
		git-r3_src_unpack
	fi
}

src_prepare() {
	default

	sed -i \
		-e 's:^\(CFLAGS[[:space:]]*=\).*$:\1 $(OPTCFLAGS) -Wall:' \
		-e 's:^\(LDFLAGS[[:space:]]*=\).*$:\1 $(OPTLDFLAGS):' \
		-e 's:^\(CC[[:space:]]* =\).*$:\1$(OPTCC):' \
		-e 's:^\(AR[[:space:]]* =\).*$:\1$(OPTAR):' \
		-e "s:\(PYTHON_PATH[[:space:]]\+=[[:space:]]\+\)\(.*\)$:\1${EPREFIX}\2:" \
		-e "s:\(PERL_PATH[[:space:]]\+=[[:space:]]\+\)\(.*\)$:\1${EPREFIX}\2:" \
		Makefile contrib/svn-fe/Makefile || die "sed failed"

	# Fix docbook2texi command
	sed -r -i 's/DOCBOOK2X_TEXI[[:space:]]*=[[:space:]]*docbook2x-texi/DOCBOOK2X_TEXI = docbook2texi.pl/' \
		Documentation/Makefile || die "sed failed"

	# Never install the private copy of Error.pm (bug #296310)
	sed -i \
		-e '/private-Error.pm/s,^,#,' \
		perl/Makefile.PL
}

git_emake() {
	# bug #320647: PYTHON_PATH
	PYTHON_PATH="${PYTHON}"
	emake ${MY_MAKEOPTS} \
		DESTDIR="${D}" \
		OPTCFLAGS="${CFLAGS}" \
		OPTLDFLAGS="${LDFLAGS}" \
		OPTCC="$(tc-getCC)" \
		OPTAR="$(tc-getAR)" \
		prefix="${EPREFIX}"/usr \
		htmldir="${EPREFIX}"/usr/share/doc/${PF}/html \
		sysconfdir="${EPREFIX}"/etc \
		PYTHON_PATH="${PYTHON_PATH}" \
		PERL_PATH="${EPREFIX}/usr/bin/perl" \
		PERL_MM_OPT="" \
		GIT_TEST_OPTS="--no-color" \
		V=1 \
		"$@"
}

src_configure() {
	exportmakeopts
}

src_compile() {
	#if use perl ; then
	git_emake perl/PM.stamp || die "emake perl/PM.stamp failed"
	git_emake perl/perl.mak || die "emake perl/perl.mak failed"
	#fi
	git_emake || die "emake failed"

	cd "${S}"/Documentation
	if [[ ${PV} == *9999 ]] ; then
		git_emake man \
			|| die "emake man failed"
		if use doc ; then
			git_emake info html \
				|| die "emake info html failed"
		fi
	else
		if use doc ; then
			git_emake info \
				|| die "emake info html failed"
		fi
	fi
}

src_install() {
	git_emake install || die "make install failed"

	rm -rf "${ED}"usr/share/gitweb || die
	rm -rf "${ED}"usr/share/git-core/templates || die
	rm -rf "${ED}"usr/share/git-gui || die
	rm -rf "${ED}"usr/share/gitk || die

	local myrelfile=""
	for myfile in "${ED}"usr/libexec/git-core/* "${ED}"usr/$(get_libdir)/* "${ED}"usr/share/man/*/* "${ED}"usr/bin/* ; do
		# image dir contains the keyword "cvs"
		myrelfile="${myfile/${ED}}"
		case "${myrelfile}" in
			*cvs*)
				true ;;
			*)
				rm -rf "${myfile}" || die ;;
		esac
	done

	local libdir="${ED}"usr/$(get_libdir)
	if [ -d "${libdir}" ]; then
		# must be empty
		rmdir "${libdir}" || die
	fi

	doman man*/*cvs* || die
	if use doc; then
		docinto /
		dodoc Documentation/*cvs*.txt
		docinto /html
		dodoc Documentation/*cvs*.html
	fi

	# kill empty dirs from ${ED}
	find "${ED}" -type d -empty -delete || die
}
