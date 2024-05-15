#!/bin/bash
set -euo pipefail

spack env activate peanuts

function sqrt() {
  echo "$1" | awk '{print sqrt($1)}'
}

MAX_NPROCS=16
MPI_HOSTS="chris90:${MAX_NPROCS},chris91:${MAX_NPROCS}"
TIMESTAMP=$(date +%Y.%m.%d-%H.%M.%S)
LD_PRELOAD=$(spack location -i peanuts)/lib/peanuts_c/libpeanuts_c.so
PMEM_PATH=/dev/dax0.0
PMEM_SIZE=0 # use all
SRC_DIR=$(dirname $(readlink -f "$0"))
OUTPUT_DIR=$(readlink -f "$SRC_DIR/../raw/rdbench/$TIMESTAMP")
ROMIO_HINTS="${SRC_DIR}/romio_hints"

# prepare output directory
mkdir -p "$OUTPUT_DIR"

ppn=16
# strong scaling
rdbench_length=$((32*2**10)) # 32k * 32k * sizeof(double) = 8 GiB/node

runid=0
for nnodes in 2 1; do
  np=$((ppn * nnodes))
  test_file="${OUTPUT_DIR}/o_${nnodes}"

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

  cmd_rdbench=(
    rdbench
    --length "$rdbench_length"
    --output "$test_file"
    --nomkdir
    --iotype view
    --steps 640
    --interval 64
    --novalidate
    --disable-initial-output
    --prettify
    --xnp 4
    --nosync
  )

  cmd_benchmark=(
    "${cmd_mpirun[@]}"
    -mca hook_peanuts_load false
    -mca hook_peanuts_save true
    "${cmd_rdbench[@]}"
  )

  echo "${cmd_benchmark[@]}"
  "${cmd_benchmark[@]}" > "${OUTPUT_DIR}/rdbench_${runid}.json"
  runid=$((runid + 1))

  rm "$test_file"* || true
done
