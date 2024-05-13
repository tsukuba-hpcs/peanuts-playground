#!/bin/bash
set -euo pipefail

spack env activate dev

MAX_NPROCS=$(nproc)
MPI_HOSTS="h1:${MAX_NPROCS},h2:${MAX_NPROCS},h3:${MAX_NPROCS},h4:${MAX_NPROCS}"
TIMESTAMP=$(date +%Y.%m.%d-%H.%M.%S)
LD_PRELOAD=$(spack location -i peanuts)/lib/peanuts_c/libpeanuts_c.so
PMEM_PATH=/tmp/pseudo_pmem
PMEM_SIZE=$((4 * 2 ** 30)) # 4 GiB per node
SRC_DIR=$(dirname $(readlink -f "$0"))
OUTPUT_DIR=$(readlink -f "$SRC_DIR/../raw/ior/$TIMESTAMP")
ROMIO_HINTS="${SRC_DIR}/romio_hints"

rm -f "${PMEM_PATH}"

# prepare output directory
mkdir -p "$OUTPUT_DIR"

# prepare pmem
touch "${PMEM_PATH}"
truncate -s "$PMEM_SIZE" "${PMEM_PATH}"

ppn=1
min_io_size_per_proc=$((4 * 2 ** 20)) # 4 MiB
segment_count=1
xfer_size_list=(
  2M 1M
  # 512K 256K 128K 64K
  47008
  32K 16K 8K
  # 4K 2K 1K 512 256
)

runid=0
for nnodes in 1 2 4; do
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

    sudo sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"
    echo "${cmd_write[@]}"
    "${cmd_write[@]}"

    sudo sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"
    echo "${cmd_read_remote[@]}"
    "${cmd_read_remote[@]}"

    sudo sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"
    echo "${cmd_read_local[@]}"
    "${cmd_read_local[@]}"

    runid=$((runid + 3))

    rm "$test_file" || true

  done
done
