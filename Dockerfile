# Dockerfile
# Pierre-André Noël, May 12th 2020
# Copyright © Element AI Inc. All rights reserved.
# Apache License, Version 2.0


# See README.md for information and usage.

# NOTE:
#   This Dockerfile uses multi-stage builds.
#   https://docs.docker.com/develop/develop-images/multistage-build/


# ******************************************************
# *** All the following images are based on this one ***
# ******************************************************
FROM quay.io/pypa/manylinux2014_x86_64 AS common

# We're only supporting Python 3.6+
RUN rm -rd /opt/python/cp35-cp35m

# The versions we want in the wheels
ENV FST_VERSION "1.7.7"
ENV PYNINI_VERSION "2.1.1"


# ***********************************************************************
# *** Image providing all the requirements for building Pynini wheels ***
# ***********************************************************************
FROM common AS wheel-building-env

# Where to get OpenFST and Pynini
ENV FST_DOWNLOAD_PREFIX "http://www.openfst.org/twiki/pub/FST/FstDownload"
ENV PYNINI_DOWNLOAD_PREFIX "http://www.opengrm.org/twiki/pub/GRM/PyniniDownload"

# Get and unpack OpenFST source
RUN yum install -y wget
RUN cd /tmp \
    && wget -q ${FST_DOWNLOAD_PREFIX}/openfst-${FST_VERSION}.tar.gz \
    && tar -zxf openfst-${FST_VERSION}.tar.gz \
    && rm openfst-${FST_VERSION}.tar.gz

# Compile OpenFST (without pywrapfst; pynini has it's own)
RUN cd /tmp/openfst-${FST_VERSION} \
    # --- BEGIN PATCH ---
    # See https://github.com/kylebgorman/pynini/issues/19
    && mv configure configure.bad \
    && cat configure.bad | sed 's/-std=c++11/-std=c++17/' > configure \
    && rm configure.bad \
    && chmod +x configure \
    # --- END PATCH ---
    && ./configure --enable-grm \
    && make --jobs=4 \
    && make install \
    && rm -rd /tmp/openfst-${FST_VERSION}


# Get and unpack Pynini source
RUN mkdir -p /src && cd /src \
    && wget -q ${PYNINI_DOWNLOAD_PREFIX}/pynini-${PYNINI_VERSION}.tar.gz \
    && tar -zxf pynini-${PYNINI_VERSION}.tar.gz \
    && rm pynini-${PYNINI_VERSION}.tar.gz


# Install requirements in all our Pythons
COPY requirements.txt /src/pynini-${PYNINI_VERSION}/requirements.txt
RUN for PYBIN in /opt/python/*/bin; do \
    "${PYBIN}/pip" install --upgrade pip -r /src/pynini-${PYNINI_VERSION}/requirements.txt \
    || exit 1; done


# **********************************************************
# *** Image making pynini wheels (placed in /wheelhouse) ***
# **********************************************************
FROM wheel-building-env AS build-wheels

# Compile the wheels to a temporary directory
RUN for PYBIN in /opt/python/*/bin; do \
    "${PYBIN}/pip" wheel /src/pynini-${PYNINI_VERSION} -w /tmp/wheelhouse/ \
    || exit 1; done

# Bundle external shared libraries into the wheels
# See https://github.com/pypa/manylinux/tree/manylinux2014
RUN for whl in /tmp/wheelhouse/*.whl; do \
    auditwheel repair "$whl" --plat manylinux2014_x86_64 -w /wheelhouse/ \
    || exit 1; done

# Remove the non-repaired wheels to reduce confusion
RUN rm -rd /tmp/wheelhouse


# ******************************************************
# *** Install wheels in a fresh (OpenFst-free) image ***
# ******************************************************
FROM common AS install-pynini-from-wheel

# Grab the wheels (but just the wheels) from the previous image
COPY --from=build-wheels /wheelhouse /wheelhouse

# Install the wheels in all our Pythons
RUN for PYBIN in /opt/python/*/bin; do \
    "${PYBIN}/pip" install pynini --no-index -f /wheelhouse || exit 1; done


# **************************
# *** Run pynini's tests ***
# **************************
FROM install-pynini-from-wheel AS run-tests

# Copy Pynini's tests and testing assets (but not Pynini itself)
COPY --from=wheel-building-env /src/pynini-${PYNINI_VERSION}/pynini_test.py /tests/pynini_test.py
COPY --from=wheel-building-env /src/pynini-${PYNINI_VERSION}/testdata /tests/testdata

# Run Pynini's tests for each of our Pythons
RUN cd /tests && for PYBIN in /opt/python/*/bin; do \
    "${PYBIN}/python" pynini_test.py -v -f || exit 1; done
