
includedir = $(top_builddir)/includes/

vapidir = $(top_builddir)/vapi/

#
# Common
#
AM_CFLAGS = \
	-O3 \
	-include config.h \
	-I $(includedir) \
	$(BASE_CFLAGS)

VALAFLAGS = \
	--debug \
	--vapidir $(vapidir)

CLEANFILES = \
	$(includedir)/*.h \
	$(noinst_LTLIBRARIES:.la=.vapi) \
	$(SOURCES:.vala=.c)


#
# Libraries
#
noinst_LTLIBRARIES = \
	libutils.la \
	libvm.la \
	libmlgp.la



#
# libutils
#
libutils_la_SOURCES = \
	utils/dataformat.vala \
	utils/stats.vala \
	utils/logging.vala \
	utils/shuntingyard.vala

libutils_la_VALAFLAGS = \
	--library $(vapidir)/libutils --header $(includedir)/libutils.h \
	--pkg gio-2.0 --pkg gee-0.8 --pkg posix

libutils_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(GEE_CFLAGS)

#
# libvm
#
libvm_la_SOURCES = \
	vm/vm.vala \
	vm/vm_tools.vala \
	vm/instruction.vala

libvm_la_VALAFLAGS = \
	--library $(vapidir)/libvm --header $(includedir)/libvm.h \
	--pkg gio-2.0

#
# libmlgp
#
libmlgp_la_SOURCES = \
	lgp/common.vala \
	lgp/individual.vala \
	lgp/population.vala \
	lgp/subpopulation.vala \
	lgp/symbolic_regression.vala \
	lgp/problems.vala \
	lgp/nsga2_deb.vala

libmlgp_la_VALAFLAGS = \
	--library $(vapidir)/liblgp --header $(includedir)/liblgp.h \
	--pkg gio-2.0 --pkg gee-0.8 \
	--pkg posix --pkg libvm --pkg libutils

libmlgp_la_CFLAGS = \
	$(AM_CFLAGS) \
	$(GEE_CFLAGS)

libmlgp_la_LIBADD = \
	libvm.la \
	libutils.la \
	$(GEE_LIBS)

