# cutseq-sif

Container image for [cutseq](https://cutseq.yech.science), built so that Singularity on an HPC
cluster can pull it by URL — the same way nf-core modules pull their biocontainers.

```
ghcr.io/typekey/cutseq:0.0.68
```

```bash
module load singularity
singularity pull docker://ghcr.io/typekey/cutseq:0.0.68
./cutseq_0.0.68.sif cutseq --version      # -> cutseq 0.0.68
```

## Why this exists

cutseq is **not packaged in bioconda** (`bioconda-recipes/recipes/cutseq` → 404), so none of the
usual container sources have it:

| source | cutseq available? |
|---|---|
| `quay.io/biocontainers/…` | no |
| `depot.galaxyproject.org/singularity/…` | no |
| PyPI | **yes** — pure-Python wheel |

This image is a thin wrapper around the PyPI package.

## Contents

`python:3.12-slim` + `cutseq==0.0.68` + `cutadapt==5.0` + `procps`.

Everything installs from prebuilt manylinux wheels, so no compiler is needed and the image stays
small:

* `cutseq-0.0.68-py3-none-any.whl` — pure Python
* `cutadapt-5.0` — `cp312 manylinux_2_17_x86_64` wheel

**Versions are pinned deliberately.** cutseq only requires `cutadapt~=5.0`, which floats up to 5.2+;
an unpinned install resolves to cutadapt 5.2. The eCLIP trimming benchmark this image was built for
was validated against **cutadapt 5.0**, so the image pins 5.0 to reproduce it. To move forward, bump
`CUTADAPT_VERSION` in the `Dockerfile` and re-validate.

`procps` is included because Nextflow's task wrapper calls `ps` to collect runtime metrics; without
it every task logs a warning.

## Building

Pushing to `main` (or running the workflow manually) builds and pushes the image via GitHub Actions
— see [`.github/workflows/build-cutseq.yml`](.github/workflows/build-cutseq.yml). No secrets are
required; the workflow uses the automatic `GITHUB_TOKEN`.

> **One-time step after the first successful build:** make the package public at
> <https://github.com/users/typekey/packages/container/cutseq/settings> → Change visibility →
> Public. Otherwise Singularity cannot pull it anonymously from the cluster.

To build locally instead, on any machine with Docker:

```bash
docker build -t ghcr.io/typekey/cutseq:0.0.68 .
docker push ghcr.io/typekey/cutseq:0.0.68
```

## Use in Nextflow

Matching the convention used by the nf-core modules:

```groovy
process CUTSEQ {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://ghcr.io/typekey/cutseq:0.0.68' :
        'ghcr.io/typekey/cutseq:0.0.68' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.cutseq.fastq.gz"), emit: reads
    tuple val(meta), path("*.json")           , emit: json
    path  "versions.yml"                      , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args   = task.ext.args   ?: '-A INLINE -m 18'
    """
    cutseq ${reads[0]} ${reads[1]} $args -t $task.cpus \\
        -o ${prefix}_R1.cutseq.fastq.gz ${prefix}_R2.cutseq.fastq.gz \\
        -s ${prefix}_R1.short.fastq.gz  ${prefix}_R2.short.fastq.gz \\
        -u ${prefix}_R1.untrimmed.fastq.gz ${prefix}_R2.untrimmed.fastq.gz \\
        --json-file ${prefix}.cutseq.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cutseq: \$(cutseq --version | sed 's/^cutseq //')
    END_VERSIONS
    """
}
```

Singularity resolves `docker://…` itself — there is no separate `.sif` to manage.

### Caching on a cluster

Set a shared cache so every job reuses one converted `.sif` instead of re-pulling:

```groovy
singularity {
    enabled    = true
    autoMounts = true
    cacheDir   = '/path/to/singularity_cache'
}
```

If compute nodes have no outbound internet, **pre-pull the image once from a login node** before
submitting jobs.

## Note on the repository name

The image is a normal OCI/Docker image; Singularity converts it to a `.sif` on pull. The repo is
named `cutseq-sif` for the use case, not because it ships a `.sif` artifact. If a downloadable
`.sif` is wanted (useful for fully offline clusters), the workflow can be extended to build one with
`singularity build` and attach it to a GitHub Release.

## Upstream

cutseq is by Ye Chang (<yech1990@gmail.com>) — <https://github.com/y9c/cutseq>. This repository only
packages it; all credit for the tool goes upstream.
