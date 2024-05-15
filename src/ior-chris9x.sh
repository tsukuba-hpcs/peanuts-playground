#!/bin/bash
set -euo pipefail

spack env activate peanuts

MAX_NPROCS=16
MPI_HOSTS="chris90:${MAX_NPROCS},chris91:${MAX_NPROCS}"
TIMESTAMP=$(date +%Y.%m.%d-%H.%M.%S)
LD_PRELOAD=$(spack location -i peanuts)/lib/peanuts_c/libpeanuts_c.so
PMEM_PATH=/dev/dax0.0
PMEM_SIZE=0 # use all
SRC_DIR=$(dirname $(readlink -f "$0"))
OUTPUT_DIR=$(readlink -f "$SRC_DIR/../raw/ior/$TIMESTAMP")
ROMIO_HINTS="${SRC_DIR}/romio_hints"

# prepare output directory
mkdir -p "$OUTPUT_DIR"

ppn=16
min_io_size_per_proc=$((20 * 2 ** 30)) # 20 GiB per proc, 320 GiB per node
segment_count=1
xfer_size_list=(
  # 2M 1M 512K 256K 128K 64K
  # 47008
  32K
  # 16K 8K 4K 2K 1K 512
  # 256
)

runid=0
for nnodes in 2 1; do
  np=$((ppn * nnodes))

  cmd_mpirun=(
    mpirun
    -H "$MPI_HOSTS"
    -x PATH
    -x LD_PRELOAD="${LD_PRELOAD}"
    -x ROMIO_FSTYPE_FORCE=peanuts:
    # -x ROMIO_PRINT_HINTS=1
    -x ROMIO_HINTS="${ROMIO_HINTS}"
    -mca hook_peanuts_pmem_path "${PMEM_PATH}"
    -mca hook_peanuts_pmem_size "${PMEM_SIZE}"
    # -mca osc ucx
    -mca io romio341
    -np "$np"
    -map-by "ppr:${ppn}:node"
  )


  for xfer_size_human in "${xfer_size_list[@]}"; do
    xfer_size=$(numfmt --from=iec "$xfer_size_human")
    block_size=$(((min_io_size_per_proc + segment_count - 1) / segment_count))
    block_size=$(((block_size + xfer_size - 1) / xfer_size * xfer_size))
    test_file="${OUTPUT_DIR}/testfile_${xfer_size_human}"

    cmd_ior=(
      ior
      -a MPIIO
      -l timestamp
      -g             # intraTestBarriers – use barriers between open, write/read, and close
      -G -1401473791 # setTimeStampSignature – set value for time stamp signature
      -k             # keepFile – don’t remove the test file(s) on program exit
      -e             # fsync
      -i 1
      -s "$segment_count"
      -b "$block_size"
      -t "$xfer_size"
      -o "$test_file"
      -O "summaryFormat=JSON"
    )

    cmd_write=(
      "${cmd_mpirun[@]}"
      -mca hook_peanuts_load false
      -mca hook_peanuts_save true
      "${cmd_ior[@]}"
      -O "summaryFile=${OUTPUT_DIR}/ior_summary_$((runid)).json"
      -w
    )

    cmd_read_remote=(
      "${cmd_mpirun[@]}"
      -mca hook_peanuts_load true
      -mca hook_peanuts_save true
      "${cmd_ior[@]}"
      -O "summaryFile=${OUTPUT_DIR}/ior_summary_$((runid+1)).json"
      -r
      -C
      -Q 1
    )

    cmd_read_local=(
      "${cmd_mpirun[@]}"
      -mca hook_peanuts_load true
      -mca hook_peanuts_save false
      "${cmd_ior[@]}"
      -O "summaryFile=${OUTPUT_DIR}/ior_summary_$((runid+2)).json"
      -r
    )

    echo "${cmd_write[@]}"
    "${cmd_write[@]}"

    echo "${cmd_read_remote[@]}"
    "${cmd_read_remote[@]}"

    echo "${cmd_read_local[@]}"
    "${cmd_read_local[@]}"

    runid=$((runid + 3))

    rm "$test_file" || true

  done
done
