# Copyright 2009-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5
S=${WORKDIR}/andor
MODULE_NAMES="bitflow(bitflow:${S}/bitflow/drv/)"
MODULESD_BITFLOW_DOCS="bitflow/README_dist"
MODULESD_BITFLOW_ADDITIONS=(
	"options /sbin/modprobe v4l2_common"
	"options /sbin/modprobe videodev"
	"options bitflow fwDelay1=200"
	"options bitflow customFlags=1"
)
inherit linux-mod multilib

DESCRIPTION="SDK library for scientific CMOS cameras"
HOMEPAGE="http://www.andor.com/software/sdk/"
SRC_URI="https://www.andor.com/my/ -> andor-sdk3-${PV}.tgz"

LICENSE="Andor-EULA"
SLOT="3"
KEYWORDS="~amd64 ~x86"
IUSE=""

RESTRICT="fetch"

DEPEND=""
RDEPEND=""

PREFIX=/opt/andor-3
LIBDIR=${PREFIX}/$(get_libdir)
SYSCONFDIR=${PREFIX}/etc
DOCDIR=${PREFIX}/doc

pkg_nofetch() {
	einfo "Due to license restrictions, download:"
	einfo "${SRC_URI}"
	einfo "and place it in ${DISTDIR}"
}

pkg_setup() {
	# Check kernel has v4l to run BitFlow framegrabber card.
	if kernel_is ge 2 6 38; then
		CONFIG_CHECK="VIDEO_V4L2"
		ERROR_V4L2="Kernel must be compiled with V4L2 support!"
	else
		CONFIG_CHECK="VIDEO_V4L1_COMPAT"
		ERROR_V4L1_COMPAT="Kernel must be compiled with V4L1_COMPAT support!"
		MODULESD_BITFLOW_ADDITIONS[0]="options /sbin/modprobe v4l1_compat"
	fi

	linux-mod_pkg_setup

	BUILD_PARAMS="-C /lib/modules/${KV_FULL}/build"
	BUILD_PARAMS+=" M=${S}/bitflow/drv/"
	BUILD_TARGETS=" "
}

src_prepare() {
	# CameraLink Framegrabber card.
	pushd bitflow/drv/
	mv Makefile_$(usex x86 32 64)b Makefile
	# Possible fix for issue #23; upstream contacted for confirmation.
	ebegin "Patching BitFlow driver"
	sed -i -e "s/VM_RESERVED/VM_DONTEXPAND | VM_DONTDUMP/" bflki.c
	eend
	popd
}

src_install() {
	# CameraLink framegrabber card.
	linux-mod_src_install

	# SDK header.
	rm inc/atmcdLXd.h			# Useless CCD SDK-2 header.
	doheader inc/*

	# SDK libraries.
	local envd=10$(basename ${PREFIX})
	echo "LDPATH=${PREFIX}" > ${envd}
	doenvd ${envd}
	pushd $(usex x86 "x86" "x86_64")
	dodir ${LIBDIR}
	dodir /usr/$(get_libdir)
	for lib in $( ls *.so.${PV} ) ; do
		# Versioned library.
		( into ${PREFIX}; dolib.so ${lib} )
		# Symlinks.
		local lib_base=${lib%%.*}
		for link_name in ${lib_base}.so{.3,} ; do
			dosym ../..${LIBDIR}/${lib} /usr/$(get_libdir)/${link_name}
		done
	done
	popd

	# Examples.
	insinto ${PREFIX}
	doins -r examples
}

pkg_postinst() {
	ewarn "Ensure your boot loader has the kernel 'nopat' parameter"
	ewarn "and that you are in the video group."
	echo
	einfo "To load the kernel module immediately, run:"
	einfo "  modprobe bitflow"
}