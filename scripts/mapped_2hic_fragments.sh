#!/bin/bash
## Nicolas Servant - 07/09/15
##

dir=$(dirname $0)

while [ $# -gt 0 ]
do
    case "$1" in
	(-c) conf_file=$2; shift;;
	(--) shift; break;;
	(-*) echo "$0: error - unrecognized option $1" 1>&2; exit 1;;
	(*)  break;;
    esac
    shift
done

##read_config $ncrna_conf
CONF=$conf_file . $dir/hic.inc.sh

## Do we have a restriction fragment file ?
MODE="RS"
GENOME_FRAGMENT_FILE=`abspath $GENOME_FRAGMENT`

if [[ $GENOME_FRAGMENT == "" || ! -f $GENOME_FRAGMENT_FILE ]]; then
    GENOME_FRAGMENT_FILE=$ANNOT_DIR/$GENOME_FRAGMENT
    if [[ ! -f $GENOME_FRAGMENT_FILE ]]; then
	MODE="DNAse"
	GENOME_FRAGMENT_FILE=""
	echo "GENOME_FRAGMENT not found. Runing DNAse Hi-C mode"
    fi
fi

## Options
opts="-v"
if [[ $MODE == "RS" ]]; then
    if [[ "${GET_PROCESS_SAM}" -eq "1" ]]; then opts=$opts" -S"; fi
    if [[ "${MIN_FRAG_SIZE}" -ge "0" && "${MIN_FRAG_SIZE}" -ne "" ]]; then opts=$opts" -t ${MIN_FRAG_SIZE}"; fi
    if [[ "${MAX_FRAG_SIZE}" -ge "0" && "${MAX_FRAG_SIZE}" -ne "" ]]; then opts=$opts" -m ${MAX_FRAG_SIZE}"; fi
    if [[ "${MIN_INSERT_SIZE}" -ge "0" && "${MIN_INSERT_SIZE}" -ne "" ]]; then opts=$opts" -s ${MIN_INSERT_SIZE}"; fi
    if [[ "${MAX_INSERT_SIZE}" -ge "0" && "${MAX_INSERT_SIZE}" -ne "" ]]; then opts=$opts" -l ${MAX_INSERT_SIZE}"; fi
fi
if [[ "${GET_ALL_INTERACTION_CLASSES}" -eq "1" ]]; then opts=$opts" -a"; fi
if [[ "${MIN_CIS_DIST}" -ge "0" && "${MIN_CIS_DIST}" -ne "" ]]; then opts=$opts" -d ${MIN_CIS_DIST}"; fi
if [[ ! -z ${ALLELE_SPECIFIC_SNP} ]]; then opts=$opts" -g XA"; fi


#for r in $(get_files_for_overlap)
for r in $(get_paired_bam)
do
    sample_dir=$(get_sample_dir ${r})
    datadir=${MAPC_OUTPUT}/data/${sample_dir}
    mkdir -p ${datadir}
    
    ## Logs
    LDIR=${LOGS_DIR}/${sample_dir}
    mkdir -p ${LDIR}
    
     if [[ $MODE == "DNAse" ]]; then
	cmd="${PYTHON_PATH}/python ${SCRIPTS}/mapped_2hic_dnase.py ${opts} -r ${r} -o ${datadir}"
	exec_cmd $cmd > ${LDIR}/mapped_2hic_dnase.log 2>&1
    else
	cmd="${PYTHON_PATH}/python ${SCRIPTS}/mapped_2hic_fragments.py ${opts} -f ${GENOME_FRAGMENT_FILE} -r ${r} -o ${datadir}"
        exec_cmd $cmd > ${LDIR}/mapped_2hic_fragments.log 2>&1
     fi
    ## Valid pairs are already sorted
    outVALID=`basename ${r} | sed -e 's/.bam$/.validPairs/'`
    #outSAM=`basename ${r} | sed -e 's/.bam$/_interaction.sam/'`
    #sortBAM=`basename ${r} | sed -e 's/.bam$/_interaction/'`
    
    echo "## Sorting valid interaction file ..." >> ${LDIR}/mapped_2hic_fragments.log 2>&1
    sort -k2,2V -k3,3n -k5,5V -k6,6n -T ${TMP_DIR} -o ${datadir}/${outVALID} ${datadir}/${outVALID} 
done



