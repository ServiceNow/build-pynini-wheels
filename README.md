# build-pynini-wheels
Build `manylinux2014_x86_64` Python wheels for `pynini`, wrapping all its dependencies.

This project heavily relies on other open-source projects.
 - See https://github.com/pypa/manylinux/tree/manylinux2014 for information about `manylinux2014`.
 - See http://www.opengrm.org/twiki/bin/view/GRM/Pynini for information about `pynini`.
 - See http://www.openfst.org/twiki/bin/view/FST/WebHome for information about `OpenFst`.

## What is this?
As of the writing of these lines, the recommended installation method for Pynini was through
Conda-Forge. The enclosed `Dockerfile` gives you another alternative: build your own Python
*Platform Wheels* for `pynini` so that you may easily `pip`/`poetry`-install it in your
favourite linux.

The process differs for macOS and Windows.

## Usage

To build wheels, run:
```shell script
docker build --target=build-wheels -t build-pynini-wheels .
```

To build wheels and also run Pynini's tests, run:
```shell script
docker build --target=run-tests -t build-pynini-wheels .
```

To extract the resulting wheels from the Docker image, run:
```shell script
docker run --rm -v $(pwd):/io --user "$(id -u):$(id -g)" build-pynini-wheels cp -r /wheelhouse /io
```
Notice that this may also give you Cython wheels.

To publish these wheels to a PyPI repository (either a local one or the official https://pypi.org/ ),
you may be interested in `twine` (see https://twine.readthedocs.io/en/latest/ ).

## Maintenance?
This repository aims to create its own obsolescence by providing the `pynini` maintainer
with the means to create their own wheels. Updates may thus be "spotty" at best, and the
repository will be retired once an official alternative is available.
