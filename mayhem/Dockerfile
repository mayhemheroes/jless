# Build Stage
FROM ghcr.io/evanrichter/cargo-fuzz:latest as builder

## Dependencies
RUN apt update && apt upgrade -y libxcb-shape0-dev libxcb-xfixes0-dev

## Add source code to the build stage.
ADD . /src
WORKDIR /src

RUN echo building instrumented harnesses && \
    bash -c "pushd fuzz && cargo +nightly -Z sparse-registry fuzz build && popd" && \
    mv fuzz/target/x86_64-unknown-linux-gnu/release/jsonparser /jsonparser && \
    echo done

RUN echo building non-instrumented harnesses && \
    export RUSTFLAGS="--cfg fuzzing -Clink-dead-code -Cdebug-assertions -C codegen-units=1" && \
    bash -c "pushd fuzz && cargo +nightly -Z sparse-registry build --release && popd" && \
    mv fuzz/target/release/jsonparser /jsonparser_no_inst && \
    echo done

# Package Stage
FROM rustlang/rust:nightly

COPY --from=builder /jsonparser /jsonparser_no_inst /
COPY --from=builder \
        /usr/lib/x86_64-linux-gnu/libxcb.so.1 \
        /usr/lib/x86_64-linux-gnu/libxcb-render.so.0 \
        /usr/lib/x86_64-linux-gnu/libxcb-shape.so.0 \
        /usr/lib/x86_64-linux-gnu/libxcb-xfixes.so.0 \
        /usr/lib/x86_64-linux-gnu/libXau.so.6 \
        /usr/lib/x86_64-linux-gnu/libXdmcp.so.6 \
        /usr/lib/x86_64-linux-gnu/libbsd.so.0 \
        /usr/lib/x86_64-linux-gnu/
