
===============
 Using pmlgp
===============

:Info: http://ww.gitorious.org/pigp/ for sources.
:Author: Fabian Deutsch <fabian.deutsch@gmx.de>
:Date: Today

.. contents::


Some foundations
================

What this is about
------------------

This file is about *libmlgp*, a multi-objective symbolic regression library and *pmlgp*, a simple application based on tha library.

Symbolic regression tries to find formulas to describe a dataset. This special variant of symbolic regression is using a multi-objective optimization technique to determine compact solutions (well, many solutiosn differing in it's compactness/complexity).

So is it like LibreOffice's solver?
-----------------------------------

It does not the same, but something similar.
LibreOffice's solver *determins optimal values* (in cells) for a formula (in a cell) to mini- or maximize a result.
pmlgp tries to *determins compromise formulas* for values. So a bit the other way round.


Achieving results
=================

How to build
------------

The project is written in vala (http://live.gnome.org/Vala).
Vala compiles the vala language to C (or JS) and compiles it using a common compier (gcc, clang, ...).

A recent version (something like 0.11) is needed to run pmlgp.
Besides vala, libgee is needed. Libgee provides a set of common datastructures (like sets and hashtables) which are used by pmlgp. 

All other build dependencies are similar to the ones required by GNOME:

 - autotools
 - gcc
 - DBus (not yet used, but prepared)
 - glib
 - GTK+-2.0
 - rst2pdf (to build the documentation, including this file)

Have a look at ``configure.ac`` to get more details.

OIf all requirements are fullfilled use the well known ``autogen.sh && make`` cycle to build pmlgp.


How to run
----------

Run-time requirements:

- gnuplot installed
- pmlgp 
- a csv file.


CSV conventions
~~~~~~~~~~~~~~~
The CSV are expexcted to follow the following conventions:
 * '\\t' (tab), ',', ';' and ' ' are allowed column delimiters.
 * The first column is the target value.
 * Lines starting with an '#' are handled as comments.
 * Use a dot (.) as a decimal separator.
 * No thousands separation.

An example::

  4 2 2
  5;1;4
  6,2,4
  # s a b

If there is a trailing comment (in the above example: ``# s a b``) and the number of fields (except the ``#``) matches the number of the previous row, those fields are used as the variable names.
So: The first line is interpreted as::

  s=4
  a=2
  b=2

This is helpful, because the generated formulas contains those variable names.
If those names are *not* given, generic aliases will be created, following the scheme *r[0-9]+* for each field.

Running
~~~~~~~

pmlgp needs to be started in the src/app directory. A bug, I know :)

If you've got a file and want to find regressions use something like the following commandline::

  # nice ../pmlgp -p ~/tmp/gp -u -f my.file.csv

This will start pmlgp and solutions will be crated until the number of maxium generations is reached.
The ``-f`` switch specifiys the file to use.

By default all params have got sane defaults, that means: You can at least try to get an result with the above commandline and no modification of other switches.
A more complex commandline is::

  # nice ../pmlgp -p ~/tmp/gp -d 100 -s 5000 -g 5000 --num-calcs 3 \
    --operators=+,*,^,sin -m 0.9 -c 0.3 --constants=""

If you want to know more about the used params run::

  # ./pmlgp --help-all

.. caution:: If you are omiting the ``-f`` parameter a built-in problem is used.



All for now.

\- fabian
