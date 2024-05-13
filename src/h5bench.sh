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
PMEM_SIZE=$((8 * 2 ** 30)) # 8 GiB per node
SRC_DIR=$(dirname $(readlink -f "$0"))
OUTPUT_DIR=$(readlink -f "$SRC_DIR/../raw/h5bench/$TIMESTAMP")
ROMIO_HINTS="${SRC_DIR}/romio_hints"

rm -f "${PMEM_PATH}"

# prepare output directory
mkdir -p "$OUTPUT_DIR"

# prepare pmem
touch "${PMEM_PATH}"
truncate -s "$PMEM_SIZE" "${PMEM_PATH}"

ppn=1
write_cfg="${OUTPUT_DIR}/write.cfg"
read_cfg="${OUTPUT_DIR}/read.cfg"
test_file="${OUTPUT_DIR}/rw.h5"


runid=0
for nnodes in 2 4; do
  np=$((ppn * nnodes))

  # generate config files
  export OUTPUT_DIR
  export NNODES=$nnodes
  envsubst <"${SRC_DIR}/config/write.template.cfg" > "${write_cfg}"
  envsubst <"${SRC_DIR}/config/read.template.cfg" > "${read_cfg}"

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

  cmd_h5bench_write=(
    "${cmd_mpirun[@]}"
    -mca hook_peanuts_load false
    -mca hook_peanuts_save true
    h5bench_write
    "${write_cfg}"
    "${test_file}"
  )

  cmd_h5bench_read=(
    "${cmd_mpirun[@]}"
    -mca hook_peanuts_load true
    -mca hook_peanuts_save false
    h5bench_read
    "${read_cfg}"
    "${test_file}"
  )

  echo "${cmd_h5bench_write[@]}"
  "${cmd_h5bench_write[@]}"

  echo "${cmd_h5bench_read[@]}"
  "${cmd_h5bench_read[@]}"

  runid=$((runid + 1))

  rm "$test_file"* || true
done
