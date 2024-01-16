FROM ubuntu:latest as ubuntu_go

ENV GO_VERSION=1.21.3

RUN apt-get update
RUN apt-get install -y wget git gcc build-essential libtool autoconf unzip wget

RUN wget -P /tmp "https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz"

RUN tar -C /usr/local -xzf "/tmp/go${GO_VERSION}.linux-amd64.tar.gz"
RUN rm "/tmp/go${GO_VERSION}.linux-amd64.tar.gz"

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

WORKDIR $GOPATH

FROM ubuntu_go

WORKDIR /app

RUN wget https://github.com/Kitware/CMake/releases/download/v3.27.9/cmake-3.27.9.tar.gz && \
    tar -xzvf cmake-3.27.9.tar.gz && \
    cd cmake-3.27.9 && ./configure -- -DCMAKE_USE_OPENSSL=OFF && ./bootstrap -- -DCMAKE_USE_OPENSSL=OFF && make -j4 && make install

RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install libbrotli-dev libmupdf-dev mupdf pkg-config -y

RUN wget https://github.com/strukturag/libheif/releases/download/v1.15.2/libheif-1.15.2.tar.gz && \
    tar -xpf libheif-1.15.2.tar.gz

RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install libaom-dev -y

RUN cd libheif* && \
    ./configure --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --enable-shared --disable-static --disable-libde265 \
        --disable-dav1d --disable-go --enable-aom --disable-gdk-pixbuf --disable-rav1e --disable-tests --disable-x265 --disable-examples && \
    make -j4 && make install

RUN wget https://github.com/mm2/Little-CMS/releases/download/lcms2.15/lcms2-2.15.tar.gz && \
    tar -xpf lcms2-2.15.tar.gz && \
    cd lcms2-2.15 && \
    ./configure --enable-shared --disable-static && \
    make -j4 && make install

RUN wget -O highway-1.0.5.tar.gz https://github.com/google/highway/archive/refs/tags/1.0.5.tar.gz && \
    tar -xpf highway-1.0.5.tar.gz && mkdir -p highway-1.0.5/build && cd highway-1.0.5/build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr -DHWY_ENABLE_TESTS=OFF -DHWY_ENABLE_EXAMPLES=OFF -DHWY_WARNINGS_ARE_ERRORS=OFF ../ && \
    make -j4 && make install

RUN wget -O libjxl-0.8.2.tar.gz https://github.com/libjxl/libjxl/archive/refs/tags/v0.8.2.tar.gz && \
    tar -xpf libjxl-0.8.2.tar.gz && mkdir -p libjxl-0.8.2/build && \
    cd libjxl-0.8.2/build && \
    cmake -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DJPEGXL_ENABLE_BENCHMARK=OFF \
        -DJPEGXL_ENABLE_COVERAGE=OFF -DJPEGXL_ENABLE_FUZZERS=OFF -DJPEGXL_ENABLE_SJPEG=OFF -DJPEGXL_WARNINGS_AS_ERRORS=OFF \
        -DJPEGXL_ENABLE_SKCMS=OFF -DJPEGXL_ENABLE_VIEWERS=OFF -DJPEGXL_ENABLE_PLUGINS=OFF -DJPEGXL_ENABLE_DOXYGEN=OFF \
        -DJPEGXL_ENABLE_MANPAGES=OFF -DJPEGXL_ENABLE_JNI=OFF -DJPEGXL_ENABLE_JPEGLI_LIBJPEG=OFF -DJPEGXL_ENABLE_TCMALLOC=OFF \
        -DJPEGXL_ENABLE_EXAMPLES=OFF -DJPEGXL_ENABLE_TOOLS=OFF -DJPEGXL_ENABLE_OPENEXR=OFF -DBUILD_TESTING=OFF \
        -DJXL_HWY_DISABLED_TARGETS_FORCED=ON -DJPEGXL_FORCE_SYSTEM_BROTLI=ON -DJPEGXL_FORCE_SYSTEM_HWY=ON ../ && \
    make -j4 && make install

RUN wget -O ImageMagick-7.1.1-15.tar.gz https://github.com/ImageMagick/ImageMagick/archive/refs/tags/7.1.1-15.tar.gz && \
    tar -xpf ImageMagick-7.1.1-15.tar.gz && \
    cd ImageMagick-7.1.1-15 && \
    ./configure --enable-shared --disable-static --enable-zero-configuration \
        --without-frozenpaths --without-utilities --disable-hdri --disable-opencl --without-modules --without-magick-plus-plus --without-perl \
        --without-bzlib --without-x --without-zip --with-zlib --without-dps --without-djvu --without-autotrace --without-fftw \
        --without-fpx --without-fontconfig --without-freetype --without-gslib --without-gvc --without-jbig --without-openjp2 \
        --without-lcms --without-lqr --without-lzma --without-openexr --without-pango --without-raw --without-rsvg --without-wmf \
        --without-xml --disable-openmp --with-jpeg --with-heic --with-jxl --with-png --with-tiff --with-webp  && \
    make -j4 && make install && ldconfig /user/local/lib

# Download Go modules
COPY go.mod go.sum ./
RUN go mod download && go mod verify

COPY *.go convert.sh ./

RUN go install -tags static github.com/gen2brain/cbconvert/cmd/cbconvert@latest

RUN useradd -ms /bin/bash cbuser

RUN mkdir /app/output && chown cbuser /app/output && chmod +x /app/convert.sh

USER cbuser
# Run
CMD ["/app/convert.sh"]