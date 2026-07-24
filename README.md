# cutseq-sif

Container images for [cutseq](https://github.com/y9c/cutseq) — cutseq `0.0.68` + cutadapt `5.2`.

## Docker

```bash
docker pull ghcr.io/typekey/cutseq:0.0.68-ca5.2
```

## Singularity / Apptainer

```bash
singularity pull docker://ghcr.io/typekey/cutseq:0.0.68-ca5.2
```

## Prebuilt `.sif`

```bash
wget https://github.com/typekey/cutseq-sif/releases/download/v0.0.68/cutseq_0.0.68.sif
```

## Tags

| tag | |
|---|---|
| `0.0.68-ca5.2` | both tools pinned, immutable |
| `0.0.68` | cutseq version, moves if cutadapt is bumped |
| `latest` | most recent build |

## Upstream

cutseq by Ye Chang — <https://github.com/y9c/cutseq>
