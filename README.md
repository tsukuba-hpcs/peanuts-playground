# peanuts-playground

## Getting Started

We have prepared a test environment for PEANUTS in a Docker container. While actual persistent memory is not available, you can verify the operation of PEANUTS. Using Docker Compose, we will build a virtual cluster consisting of four containers. MPI can be utilized between containers using OpenMPI-peanuts.

We are testing with VSCode and the devcontainer extension, so please follow the steps below to set up the environment:

1. Install [VSCode](https://code.visualstudio.com/)
2. Install Docker by referring to [Developing inside a Container](https://code.visualstudio.com/docs/devcontainers/containers)
3. Install the [Remote Development](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack) extension

Next, clone this repository, open it in VSCode, and build the devcontainer:

```console
git clone --recursive git@github.com:tsukuba-hpcs/peanuts-playground.git
cd peanuts-playground
code .
```

Use the command palette to open the project in a container.  
`> Dev Containers: Rebuild and Reopen in Container`

Once the container starts, build PEANUTS with the following commands. We use spack for the installation of PEANUTS. Additionally, Python modules are installed with Pip for later visualization.
```console
# in the container peanuts-h1

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

spack env create dev spack/envs/dev/spack.yaml
spack env activate dev
spack concretize -fU
spack install
```

## Run Benchmarks

Once the `spack install` command is successfully completed, the following tools will be installed:
- OpenMPI integrated with PEANUTS (mpirun)
- Benchmarks:
  - ior
  - rdbench
  - h5bench_write / h5bench_read

Using these tools, you can run the benchmarks described in the PEANUTS paper. However, there are some limitations in the container environment:
- Since persistent memory is not available, we use the `/tmp/pseudo_pmem` file as a pseudo PMEM device.
- When running with process per node (PPN) > 1, `MPI_Win_create` fails to register file-backed memory. Therefore, please run `mpirun` with PPN=1.

We have prepared scripts to run the benchmarks inside the container:
- `src/ior.sh`
- `src/rdbench.sh`
- `src/h5bench.sh`

When executed, the results will be output to the `raw/` directory.

```console
cd src
./ior.sh
./rdbench.sh
./h5bench.sh
```

## Plot Results

We have also prepared Jupyter notebooks to parse the logs in the `raw/` directory and create graphs:
- `src/ior.ipynb`
- `src/rdbench.ipynb`
- `src/h5bench.ipynb`

The required pip modules are installed in the `.venv/` directory. Open each Jupyter notebook, select `.venv` from the `Select Kernel` option in the upper right, and run the entire notebook.
