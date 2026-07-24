# cutseq — automatic adapter/barcode/UMI trimming for NGS
# upstream: https://cutseq.yech.science  |  https://pypi.org/project/cutseq/
#
# cutseq is not in bioconda, so no quay.io/biocontainers or
# depot.galaxyproject.org image exists; this is a purpose-built image.
#
# Everything installs from prebuilt manylinux wheels — no compiler needed,
# so the slim base stays slim:
#   cutseq  0.0.68 -> cutseq-0.0.68-py3-none-any.whl        (pure Python)
#   cutadapt 5.0   -> cp312 manylinux_2_17_x86_64 wheel
#
# Versions are PINNED on purpose: cutseq declares `cutadapt~=5.0`, which
# otherwise floats up to 5.2+. 5.0 is the version the eCLIP trimming
# benchmark was validated against, so this image reproduces those results.
# To move forward, bump CUTADAPT_VERSION and re-validate.

FROM python:3.12-slim

ARG CUTSEQ_VERSION=0.0.68
ARG CUTADAPT_VERSION=5.0

LABEL org.opencontainers.image.title="cutseq" \
      org.opencontainers.image.description="Trim sequencing adapters/barcodes/UMIs from NGS data (cutseq ${CUTSEQ_VERSION}, cutadapt ${CUTADAPT_VERSION})" \
      org.opencontainers.image.version="${CUTSEQ_VERSION}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.url="https://cutseq.yech.science" \
      org.opencontainers.image.source="https://github.com/typekey/cutseq-sif"

# procps: Nextflow's task wrapper calls `ps` to collect runtime metrics.
# Without it every task logs a warning. ~1 MB, worth including.
RUN apt-get update \
    && apt-get install -y --no-install-recommends procps \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
        "cutadapt==${CUTADAPT_VERSION}" \
        "cutseq==${CUTSEQ_VERSION}" \
    && cutseq --version \
    && cutseq --list-adapters | grep -q '^INLINE'

# Run as non-root. Singularity ignores USER (it runs as the invoking user),
# but this keeps the image safe under plain Docker too.
RUN useradd --create-home --shell /bin/bash cutseq
USER cutseq
WORKDIR /home/cutseq

CMD ["cutseq", "--help"]
