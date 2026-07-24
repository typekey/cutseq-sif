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

`python:3.12-slim` + `cutseq==0.0.68` + `cutadapt==5.2` + `procps`.

Everything installs from prebuilt manylinux wheels, so no compiler is needed and the image stays
small:

* `cutseq-0.0.68-py3-none-any.whl` — pure Python
* `cutadapt-5.2` — `cp312 manylinux_2_17_x86_64` wheel

**Versions are pinned deliberately** — both are the current latest, pinned so a rebuild is
reproducible rather than silently drifting.

cutadapt was previously held at 5.0, the version the eCLIP trimming benchmark was validated against.
Verified before moving to 5.2: on 100k read pairs cutseq 0.0.68 produces **byte-identical** output
under cutadapt 5.0 and 5.2 (same stats line, same md5 of the trimmed FASTQ), so the upgrade does not
invalidate those results.

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

## Downloadable `.sif`

Each build also publishes a Singularity image as a release asset — the practical route for clusters
whose compute nodes have no outbound internet:

```bash
wget https://github.com/typekey/cutseq-sif/releases/download/v0.0.68/cutseq_0.0.68.sif
./cutseq_0.0.68.sif cutseq --version
```

In Nextflow, point the module's `container` directive straight at the file path instead of the
`docker://` URL.

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

## Tags

| tag | meaning |
|---|---|
| `:0.0.68` | cutseq version; moves if the cutadapt pin is bumped |
| `:0.0.68-ca5.2` | fully pinned, immutable — use this when reproducibility matters |
| `:latest` | most recent build |

## Upstream

cutseq is by Ye Chang (<yech1990@gmail.com>) — <https://github.com/y9c/cutseq>. This repository only
packages it; all credit for the tool goes upstream.
