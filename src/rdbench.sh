#!/bin/bash
set -euo pipefail

spack env activate dev

function sqrt() {
  echo "$1" | awk '{print sqrt($1)}'
}

MAX_NPROCS=$(nproc)
MPI_HOSTS="h1:${MAX_NPROCS},h2:${MAX_NPROCS},h3:${MAX_NPROCS},h4:${MAX_NPROCS}"
TIMESTAMP=$(date +%Y.%m.%d-%H.%M.%S)
LD_PRELOAD=$(spack location -i peanuts)/lib/peanuts_c/libpeanuts_c.so
PMEM_PATH=/tmp/pseudo_pmem
PMEM_SIZE=$((4 * 2 ** 30)) # 4 GiB per node
SRC_DIR=$(dirname $(readlink -f "$0"))
OUTPUT_DIR=$(readlink -f "$SRC_DIR/../raw/rdbench/$TIMESTAMP")
ROMIO_HINTS="${SRC_DIR}/romio_hints"

rm -f "${PMEM_PATH}"

# prepare output directory
mkdir -p "$OUTPUT_DIR"

# prepare pmem
touch "${PMEM_PATH}"
truncate -s "$PMEM_SIZE" "${PMEM_PATH}"

ppn=1
rdbench_length_per_node=$((2**10)) # 1k * 1k * sizeof(double) = 8 MiB/node

runid=0
for nnodes in 1 4; do
  np=$((ppn * nnodes))
  rdbench_length=$((rdbench_length_per_node * $(sqrt "$nnodes")))
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
    --xnp $((1 * $(sqrt "$nnodes")))
    --nosync
  )

  cmd_benchmark=(
    "${cmd_mpirun[@]}"
    -mca hook_peanuts_load false
    -mca hook_peanuts_save true
    "${cmd_rdbench[@]}"
  )

  sudo sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"
  echo "${cmd_benchmark[@]}"
  "${cmd_benchmark[@]}" > "${OUTPUT_DIR}/rdbench_${runid}.json"
  runid=$((runid + 1))

  rm "$test_file"* || true
done
