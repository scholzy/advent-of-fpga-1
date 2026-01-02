FROM ocaml/opam:debian-13-ocaml-5.5

USER root

RUN apt update && apt install -y build-essential autoconf

RUN opam switch create 5.2.0+ox --repos ox=git+https://github.com/oxcaml/opam-repository.git,default
RUN eval $(opam env --switch 5.2.0+ox)

RUN apt install -y libgmp-dev

RUN opam install -y ocamlformat merlin ocaml-lsp-server utop parallel core_unix

RUN apt install -y pkg-config zlib1g-dev
RUN opam install -y hardcaml hardcaml_test_harness hardcaml_waveterm ppx_hardcaml
RUN opam install -y core core_unix ppx_jane rope re dune
RUN opam install -y hardcaml_circuits

USER opam

ENV OPAM_SWITCH_PREFIX='/home/opam/.opam/5.2.0+ox'
ENV OCAMLTOP_INCLUDE_PATH='/home/opam/.opam/5.2.0+ox/lib/toplevel'
ENV CAML_LD_LIBRARY_PATH='/home/opam/.opam/5.2.0+ox/lib/stublibs:/home/opam/.opam/5.2.0+ox/lib/ocaml/stublibs:/home/opam/.opam/5.2.0+ox/lib/ocaml'
ENV OCAML_TOPLEVEL_PATH='/home/opam/.opam/5.2.0+ox/lib/toplevel'
ENV MANPATH=':/home/opam/.opam/5.2.0+ox/man'
ENV PATH='/home/opam/.opam/5.2.0+ox/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

COPY --chown=opam:opam . .

RUN dune build

ENTRYPOINT ["/bin/sh"]
