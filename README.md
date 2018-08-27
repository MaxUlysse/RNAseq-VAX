
please note : This pipeline is still in alpha stage. please use at your own risk


# RNAseq-VAX - RNAseq Variante Allele Expression 
this pipeline takes already aligned data from nf-core/rnaseq pipeline and calls variants with haplotypecaller as well as allele specific variants. The aim is to follow the guidelines for variant calling by GATK. It then annoatates the variants with VEP

### Introduction
RNAseq-VAX: this pipeline takes already aligned data from NGI-RNAseq pipeline and calls variants and allele specifice variant expressions

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker / singularity containers making installation trivial and results highly reproducible.


### Documentation
The RNAseq_VAX pipeline comes with documentation about the pipeline, found in the `docs/` directory:

1. [Installation](docs/installation.md)
2. [Running the pipeline](docs/usage.md)
3. [Output and how to interpret the results](docs/output.md)


### Credits
This pipeline was written by Aron T. Skaftason ([arontommi](https://github.com/arontommi)) but mostly cannibalised from [nf-core/rnaseq](https://github.com/nf-core/rnaseq)