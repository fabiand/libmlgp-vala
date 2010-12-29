
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
# Program
#
bin_PROGRAMS = \
        pmlgp

pmlgp_SOURCES = \
	app_core.vala \
	plain_lgp.vala \
	parse_opts.vala \
	result_summarizer.vala \
	ui_simple_gnuplot.vala \
	gnplot2.vala

pmlgp_VALAFLAGS = \
        --thread \
        --pkg posix --pkg gmodule-2.0 --pkg gio-2.0 \
        --pkg libvm --pkg liblgp --pkg libutils

pmlgp_CFLAGS = \
        $(AM_CFLAGS) \
        $(DBUS_CFLAGS)

pmlgp_LDADD = \
        $(top_srcdir)/src/libutils.la \
        $(top_srcdir)/src/libvm.la \
        $(top_srcdir)/src/libmlgp.la \
        $(BASE_LIBS) $(LIBM)

