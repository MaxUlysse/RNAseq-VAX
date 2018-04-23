#!/usr/bin/env nextflow
/*
vim: syntax=groovy
-*- mode: groovy;-*-
========================================================================================
                         RNA-seq_AVC
========================================================================================
 RNA-seq_AVC Analysis Pipeline. Started 2018-02-06.
 #### Homepage / Documentation
 rna-seq_AVC
 #### Authors
 Aron T. Skaftason arontommi <aron.skaftason@ki.se> - https://github.com/arontommi>
----------------------------------------------------------------------------------------
*/


def helpMessage() {
    log.info"""
    =========================================
     RNA-seq_AVC v${version}
    =========================================
    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run rna-seq_AVC --reads '*_R{1,2}.fastq.gz' -profile docker

    Mandatory arguments:
      --reads                       Path to input data (must be surrounded with quotes)
      --genome                      Name of iGenomes reference
      --gtf                         Path to GTF file
      -profile                      Hardware config to use. docker / aws

    Options:
      --singleEnd                   Specifies that the input is single end reads

    References                      If not specified in the configuration file or you wish to overwrite any of the references.
      --fasta                       Path to Fasta reference

    Other options:
      --outdir                      The output directory where the results will be saved
      --email                       Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.
    """.stripIndent()
}



params.deduped_bam = 'T'
params.outdir = './results'
params.bamfolder = './results/markDuplicates/'
params.genome = false
params.project = false
params.fasta = params.genome ? params.genomes[ params.genome ].fasta ?: false : false
params.gtf = params.genome ? params.genomes[ params.genome ].gtf ?: false : false
params.download_fasta = false


params.rglb = '1'
params.rgpl = 'illumina'
params.rgpu = 'unit1'


wherearemyfiles = file("$baseDir/assets/where_are_my_files.txt")


if( workflow.profile == 'uppmax' || workflow.profile == 'uppmax-modules' || workflow.profile == 'uppmax-devel' ){
    if ( !params.project ) exit 1, "No UPPMAX project ID found! Use --project"
}

if (params.deduped_bam ) {
    Channel
        .fromPath(params.bamfolder+'*.bam')
        .set{bam_md}
}
else if ( !params.deduped_bam ){
    exit 1, "No Bam specified! do some algning first!"
}

if ( params.fasta ){
    if ( params.fasta.endsWith('.fa')) {
        fasta = file(params.fasta)
        fai = file(params.fasta + '.fai')
        dict = file(params.fasta - '.fa'+'.dict')
    }
    else if ( params.fasta.endsWith('.fasta')) {
        fasta = file(params.fasta)
        fai = file(params.fasta + '.fai')
        dict = file(params.fasta - '.fasta'+'.dict')
    }
}
/*
 * Readgroups added 
 */
process addReadGroups{ 
    tag "$bam_md.baseName"

    input:
    file bam_md
    val rglb from params.rglb
    val rgpl from params.rgpl
    val rgpu from params.rgpu

    output:
    set val("$name"), file("${name}.RG.bam"), file("${name}.RG.bam.bai") into rg_data

    script:
    if( task.memory == null ){
        log.info "[Picard MarkDuplicates] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this."
        avail_mem = 3
    } else {
        avail_mem = task.memory.toGiga()
    }
    name = "${bam_md.baseName}"
    """
    java -Xmx${avail_mem}g -jar \$PICARD_HOME/picard.jar AddOrReplaceReadGroups \\
        I= $bam_md \\
        O= ${name}.RG.bam \\
        RGLB=$rglb \\
        RGPL=$rgpl \\
        RGPU=$rgpu \\
        RGSM=${bam_md.baseName}

    samtools index ${bam_md.baseName}.RG.bam

    """
}
/*
 * STEP 7 SplitNCigarReads
 */
process splitNCigarReads {
    tag "$rg_bam"

    input:
    set val(name), file(rg_bam), file(rg_bam_bai) from rg_data
    file fasta
    file fai
    file dict

    output:
    set val("$name"), file("${name}_split.bam"), file("${name}_split.bam.bai") into sc_data

    script:

    """
    java -jar \$GATK_HOME/gatk-package-4.0.1.2-local.jar SplitNCigarReads \\
    -R $fasta \\
    -I $rg_bam \\
    -O ${name}_split.bam 

    samtools index ${name}_split.bam
    """
}

/*
 * STEP 7 Haplotypecaller
 */
process haplotypeCaller {
    tag "$splitNCigar_bam.baseName"
    publishDir "${params.outdir}/haplotypeCaller", mode: 'copy',
        saveAs: {filename ->
                    if (filename.endsWith(".bam") || filename.endsWith(".bam.bai")) null
                    else $filename
                    }

    input:
    set val(name), file(splitNCigar_bam), file(splitNCigar_bam_bai) from sc_data
    file fasta
    file fai
    file dict

    output:
    set val("$name"), file("$splitNCigar_bam"), file("$splitNCigar_bam_bai"), file("${name}.vcf.gz"), file("${name}.vcf.gz.tbi") into ht_data
    
    script:

    """
    java -jar \$GATK_HOME/gatk-package-4.0.1.2-local.jar HaplotypeCaller \\
    -R $fasta \\
    -I $splitNCigar_bam \\
    --dont-use-soft-clipped-bases \\
    --standard-min-confidence-threshold-for-calling 20.0 \\
    -O ${name}.vcf
    bgzip -c ${name}.vcf > ${name}.vcf.gz
    tabix -p vcf ${name}.vcf.gz
    """
}


/*
 * STEP 8 varfiltering
 */
process varfiltering {
    tag "$vcf.baseName"
    publishDir "${params.outdir}/VariantFiltration", mode: 'copy',
        saveAs: {filename ->
                    if (filename.indexOf(".bam")> 0) null
                    else filename
                    }


    input:
    set val(name), file(splitNCigar_bam), file(splitNCigar_bam_bai), file(vcf), file(vcf_tbi) from ht_data
    file fasta
    file fai
    file dict


    output:
    set val("$name"), file("$splitNCigar_bam"), file("$splitNCigar_bam_bai"), file("${name}.sorted.vcf.gz"), file("${name}.sorted.vcf.gz.tbi") into filtered_data
    
    script:

    """
    java -jar \$GATK_HOME/gatk-package-4.0.1.2-local.jar VariantFiltration \\
    -R $fasta \\
    -V $vcf \\
    -window 35 \\
    -cluster 3 \\
    -filter-name FS \\
    -filter "FS > 30.0" \\
    -filter-name QD \\
    -filter "QD < 2.0"  \\
    -O ${name}.sorted.vcf
    bgzip -c ${name}.sorted.vcf > ${name}.sorted.vcf.gz
    tabix -p vcf ${name}.sorted.vcf.gz
    """
}
 process selectvariants {
    tag "$filtered_vcf.baseName"
    publishDir "${params.outdir}/BiallelecVCF", mode: 'copy',
        saveAs: {filename ->
                    if (filename.indexOf(".bam") > 0) null
                    else filename
                    }


    input:
    set val(name), file(splitNCigar_bam), file(splitNCigar_bam_bai), file(filtered_vcf), file(vcf_tbi) from filtered_data
    file fasta
    file fai
    file dict


    output:
    set val("$name"), file("$splitNCigar_bam"), file("$splitNCigar_bam_bai"), file("${name}.biallelec.vcf.gz"), file("${name}.biallelec.vcf.gz.tbi") into BiallelecVCF

    script:

    """
    java -jar \$GATK_HOME/gatk-package-4.0.1.2-local.jar SelectVariants \\
    -R $fasta \\
    -V $filtered_vcf \\
    --restrict-alleles-to BIALLELIC \\
    -select-type SNP \\
    -O ${name}.biallelec.vcf
    bgzip -c ${name}.biallelec.vcf > ${name}.biallelec.vcf.gz 
    tabix -p vcf ${name}.biallelec.vcf.gz 
    """
}

 process allelespecificexpression {
    tag "$biallelec_vcf.baseName"
    publishDir "${params.outdir}/AlleleSpecificExpression", mode: 'copy'


    input:
    set val(name), file(splitNCigar_bam), file(splitNCigar_bam_bai), file(biallelec_vcf), file(vcf_index) from BiallelecVCF
    file fasta
    file fai
    file dict


    output:
    file "${name}.ASE.csv" into AlleleSpecificExpression
    script:

    """
    java -jar \$GATK_HOME/gatk-package-4.0.1.2-local.jar ASEReadCounter \\
    -R $fasta \\
    -I $splitNCigar_bam \\
    -V $biallelec_vcf \\
    -O ${name}.ASE.csv
    """
}