FROM openjdk:8

LABEL authors=aron.skaftason@ki.se \
    description="Docker image containing all requirements for rnaseq-vax pipeline"

# Install container-wide requrements gcc, pip, zlib, libssl, make, libncurses, fortran77, g++, R
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        g++ \
        gcc \
        gfortran \
        libbz2-dev \
        libcurl4-openssl-dev \
        libgsl-dev \
        libgsl2 \
        liblzma-dev \
        libncurses5-dev \
        libpcre3-dev \
        libreadline-dev \
        libssl-dev \
        make \
        python-dev \
        zlib1g-dev \
        cpanminus \
    && rm -rf /var/lib/apt/lists/*

# Install pip
RUN curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /opt/get-pip.py && \
    python /opt/get-pip.py && \
    rm /opt/get-pip.py


# Install GATK
RUN curl -fsSL https://github.com/broadinstitute/gatk/releases/download/4.0.1.2/gatk-4.0.1.2.zip -o /opt/gatk-4.0.1.2.zip && \
    unzip /opt/gatk-4.0.1.2.zip -d /opt/ && \
    rm /opt/gatk-4.0.1.2.zip
ENV GATK_HOME /opt/gatk-4.0.1.2

# Install PicardTools
RUN curl -fsSL https://github.com/broadinstitute/picard/releases/download/2.0.1/picard-tools-2.0.1.zip -o /opt/picard-tools-2.0.1.zip && \
    unzip /opt/picard-tools-2.0.1.zip -d /opt/ && \
    rm /opt/picard-tools-2.0.1.zip
ENV PICARD_HOME /opt/picard-tools-2.0.1

# Install SAMTools
RUN curl -fsSL https://github.com/samtools/samtools/releases/download/1.3.1/samtools-1.3.1.tar.bz2 -o /opt/samtools-1.3.1.tar.bz2 && \
    tar xvjf /opt/samtools-1.3.1.tar.bz2 -C /opt/ && \
    cd /opt/samtools-1.3.1 && \
    make && \
    make install && \
    rm /opt/samtools-1.3.1.tar.bz2

# Install bcftools
RUN curl -fsSL https://github.com/samtools/bcftools/releases/download/1.7/bcftools-1.7.tar.bz2 -o /opt/bcftools-1.7.tar.bz2 && \
    tar xvjf /opt/bcftools-1.7.tar.bz2 -C /opt/ && \
    cd /opt/bcftools-1.7 && \
    make && \
    make install && \
    rm /opt/bcftools-1.7.tar.bz2

# Install htslib
RUN curl -fsSL https://github.com/samtools/htslib/releases/download/1.7/htslib-1.7.tar.bz2 -o /opt/htslib-1.7.tar.bz2 && \
    tar xvjf /opt/htslib-1.7.tar.bz2 -C /opt/ && \
    cd /opt/htslib-1.7 && \
    make && \
    make install && \
    rm /opt/htslib-1.7.tar.bz2

#install vep

RUN cpanm DBI 

RUN git clone https://github.com/Ensembl/ensembl-vep.git /opt/ensembl-vep &&\
    cd /opt/ensembl-vep &&\
    perl INSTALL.pl

ENV \
  GENOME=GRCh37 \
  VEP_VERSION=91

# Download Genome
RUN \
  mkdir -p    \
  && cd /opt/.vep \
  && wget --quiet -O homo_sapiens_vep_${VEP_VERSION}_${GENOME}.tar.gz \
    ftp://ftp.ensembl.org/pub/release-${VEP_VERSION}/variation/VEP/homo_sapiens_vep_${VEP_VERSION}_${GENOME}.tar.gz \
  && tar xzf homo_sapiens_vep_${VEP_VERSION}_${GENOME}.tar.gz \
  && rm homo_sapiens_vep_${VEP_VERSION}_${GENOME}.tar.gz




