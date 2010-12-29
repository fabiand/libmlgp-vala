
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

plain_lgp_SOURCES = \
        app_core.vala \
        plain_lgp.vala \
        parse_opts.vala \
        result_summarizer.vala \
        ui_simple_gnuplot.vala \
	gnplot2.vala

plain_lgp_VALAFLAGS = \
        --thread \
        --pkg posix --pkg gmodule-2.0 \
        --pkg libvm --pkg liblgp --pkg libutils --pkg libgnplot --pkg gio-2.0

plain_lgp_CFLAGS = \
        $(AM_CFLAGS) \
        $(DBUS_CFLAGS)

plain_lgp_LDADD = \
        libutils.la \
        libvm.la \
        liblgp.la \
        $(BASE_LIBS) $(LIBM)

