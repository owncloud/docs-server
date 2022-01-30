# IMPORTANT INFORMATION

This manual is a dummy and *not used anywhere* in the documentation!
But it is important to be kept when content from ROOT is accessed from outside ROOT!
This dummy manual only holds links from relevant documents in ROOT. 

This is necessary because we include the navigation from ROOT in the docs repo which
then shows the product as navigation list in the main window.

## Background

It seems that there is a bug in Antora which prevents accessing content via family ressources
like `partial$` in the ROOT manual (and only from ROOT).

According:
[root module](https://docs.antora.org/antora/2.3/root-module-directory/#where-root-name-is-used)
accessing content should be possible in the ROOT manual like:

`include::version@component:ROOT:family$path-file.adoc`

but you get an error when doing so like:

`asciidoctor: ERROR: nav.adoc: line 8: include target not found: 10.9@server:ROOT:partial$nav.adoc`

It works flawless when using eg `admin_manual` instead of `ROOT`.

## SOLUTION

Because Antora is capable resolving symbolic links, see:
[Symlinks in Antora](https://docs.antora.org/antora/latest/symlinks/#what-is-a-symlink)
we can overcome this issue using a dummy module and symbolic links pointing to ressources in ROOT.
Content of ROOT can now be accessed via this dummy module normally...

Note that the navigation file (nav.adoc) **AND** all files referenced via **xref** in the navigation
(eg. index.adoc) must be linked in the dummy module.

Note for any file linked, **ONLY** use relative paths when linking like:

In directory `no_man/partials`

`ln -s ../../ROOT/partials/nav.adoc nav.adoc`
