# peanuts-playground

https://github.com/tsukuba-hpcs/peanuts-playground

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

If the benchmark fails to run, a corrupt results file may be generated and should be deleted.

## Install PEANUTS on a Real Cluster

In the PEANUTS paper, the Pegasus supercomputer at the University of Tsukuba was utilized.
However, Pegasus could not provide accounts for Artifact Evaluation.
Instead, we explain how to run PEANUTS using the chris9x cluster owned by our laboratory.

The chris9x cluster consists of two nodes, chris90 and chris91,
equipped with the second generation of Intel Optane DCPMM and InfiniBand EDR.

Perform the following tasks by connecting to chris90 via ssh.
(Sorry, git clone and build will take a while due to poor NFS)

```console
# checkout
git clone --recursive git@github.com:tsukuba-hpcs/peanuts-playground.git
cd peanuts-playground

# install python modules
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# prepre spack
source externals/spack/share/spack/setup-env.sh

# build PEANUTS and benckmarks and configuration tools with spack
spack repo add externals/spack-packages
spack env create peanuts spack/envs/chris90/spack.yaml
spack env activate peanuts
spack concretize -fU
spack install

# prepare interleaved devdax PMEM (requires root privilege)
# Preparation for DEVDAX is done in advance with root privileges.
sudo env PATH=$PATH ndctl destroy-namespace all --force
sudo env PATH=$PATH ndctl create-namespace --mode=devdax
sudo chmod 666 /dev/dax0.0
```

In practice, the final preparation of DEVDAX is done in advance with root privileges.

Checking the PMEM device.
<details><summary>ndctl list -ND (click here to show in details)</summary>

```
$ ndctl list -NDu
{
  "dimms":[
    {
      "dev":"nmem1",
      "id":"8089-a2-2106-000044f9",
      "handle":"0x11",
      "phys_id":"0x110c",
      "security":"disabled"
    },
    {
      "dev":"nmem3",
      "id":"8089-a2-2106-000041f5",
      "handle":"0x111",
      "phys_id":"0x110e",
      "security":"disabled"
    },
    {
      "dev":"nmem5",
      "id":"8089-a2-2136-000039d0",
      "handle":"0x211",
      "phys_id":"0x110d",
      "security":"disabled"
    },
    {
      "dev":"nmem7",
      "id":"8089-a2-2136-000032c1",
      "handle":"0x311",
      "phys_id":"0x110f",
      "security":"disabled"
    },
    {
      "dev":"nmem0",
      "id":"8089-a2-2106-000043e8",
      "handle":"0x1",
      "phys_id":"0x1108",
      "security":"disabled"
    },
    {
      "dev":"nmem2",
      "id":"8089-a2-2106-000044c8",
      "handle":"0x101",
      "phys_id":"0x110a",
      "security":"disabled"
    },
    {
      "dev":"nmem4",
      "id":"8089-a2-2136-0000387d",
      "handle":"0x201",
      "phys_id":"0x1109",
      "security":"disabled"
    },
    {
      "dev":"nmem6",
      "id":"8089-a2-2136-00003938",
      "handle":"0x301",
      "phys_id":"0x110b",
      "security":"disabled"
    }
  ],
  "namespaces":[
    {
      "dev":"namespace0.0",
      "mode":"devdax",
      "map":"dev",
      "size":"992.25 GiB (1065.42 GB)",
      "uuid":"1907bd57-f250-40ca-ad03-8ab614871f31",
      "chardev":"dax0.0",
      "align":2097152
    }
  ]
}

```
</details>

We have an interleaved PMEM namespace with 8 DIMMs. total size is 1 TB per node.

## Run Benchmarks on a Real Cluster

We have prepared scripts for running benchmarks on the chris9x cluster with actual PMEM devices.
- `src/ior-chris9x.sh`
- `src/rdbench-chris9x.sh`
- `src/h5bench-chris9x.sh`

Before running, ensure that Spack is enabled.
```console
source externals/spack/share/spack/setup-env.sh
cd src
./ior-chris9x.sh
./rdbench-chris9x.sh
./h5bench-chris9x.sh
```

PEANUTS automatically maps `/dev/dax0.0` into the virtual address space immediately after `MPI_Init()`
and registers PMEM to the RDMA-capable NIC with `MPI_Win_create()`.
Parameters can be passed to PEANUTS through the mpirun runtime command,
but they are already set in the scripts above.
You can check the settings in detail using the following command.


<details><summary>ompi_info</summary>

```console
ompi_info --params hook peanuts --level 3
                MCA hook: peanuts (MCA v2.1.0, API v1.0.0, Component v5.0.0)
        MCA hook peanuts: ---------------------------------------------------
        MCA hook peanuts: parameter "hook_peanuts_pmem_path" (current value:
                          "/dev/dax0.0", data source: default, level: 3
                          user/all, type: string)
                          Path to the pmem device
        MCA hook peanuts: parameter "hook_peanuts_pmem_size" (current value:
                          "0", data source: default, level: 3 user/all, type:
                          size_t)
                          Size of the pmem device
        MCA hook peanuts: parameter "hook_peanuts_save" (current value:
                          "true", data source: default, level: 3 user/all,
                          type: bool)
                          Save volatile state to the pmem
                          Valid values: 0|f|false|disabled|no|n,
                          1|t|true|enabled|yes|y
        MCA hook peanuts: parameter "hook_peanuts_load" (current value:
                          "false", data source: default, level: 3 user/all,
                          type: bool)
                          Load volatile state from the pmem
                          Valid values: 0|f|false|disabled|no|n,
                          1|t|true|enabled|yes|y
        MCA hook peanuts: parameter "hook_peanuts_enable" (current value:
                          "true", data source: default, level: 3 user/all,
                          type: bool)
                          Enable peanuts
                          Valid values: 0|f|false|disabled|no|n,
                          1|t|true|enabled|yes|y
```

</details>



If other users are using `/dev/dax0.0`, it cannot be executed simultaneously.

While IOR is run with various transfer sizes in the paper,
the script executes it with a 32KiB transfer size.
If you want to try other transfer sizes, uncomment the xfer_size_list variable in `ior-chris9x.sh`.

## Plot Results on a Real Cluster

You can visualize the results on the chris9x cluster. To do so, connect to chris90 using VSCode with the Remote SSH extension. Alternatively, copy the log files to your local machine using scp and run Jupyter Notebook within your local devcontainer.

Preliminary experiments have measured the parallel I/O performance of the PMEM devices on a single node of the chris9x cluster.  
[range3/pmembench benchmark result](https://github.com/range3/pmembench/blob/4db7408da4a5a5767c93657cc03cd933f3fac61c/eval/README.md)

The blue line in this graph represents the results for the Optane DCPMM 200 series (second generation) on chris9x. The peak write performance is 15 GiB/s, but it drops to about 10 GiB/s when accessed with 16 threads. This is a characteristic of the second generation of Optane DCPMM. For reads, it achieves around 42 GiB/s with 16 threads and a 32 KiB transfer size.

Regarding network performance, the chris9x cluster is equipped with InfiniBand EDR, providing 100 Gbps == 12.5 GB/s per node.

When visualizing the results of ior, success is indicated if the performance for 32 KiB and 2 nodes is close to:
- Write: 20 GiB/s
- Remote Read: 25 GB/s == 23.3 GiB/s
- Local Read: 84 GiB/s


# Differences from PEANUTS paper
- Pegasus supercomputer vs Chris9x

|            | Pegasus                             | Chris9x                            |
| ---------- | ----------------------------------- | ---------------------------------- |
| PMEM       | Optane DCPMM 300 series             | Optane DCPMM 200 series            |
| NETWORK    | InfiniBand HDR200                   | InfiniBand EDR                     |
| CPU        | Xeon Platinum 8468, 2.1GHz 48 cores | Xeon Gold 6326, 2.90GHz 16 cores   |
| Node count | 100                                 | 2                                  |
- RDBench could not evaluate weak scaling on 2 nodes due to the limitations of the application, so I wrote a script with strong scaling in chris9x.

# References
- [PEANUTS core libraies](https://github.com/tsukuba-hpcs/peanuts)
- [OpenMPI with PEANUTS](https://github.com/tsukuba-hpcs/ompi-peanuts)
- [Spack packages for installing PEANUTS](https://github.com/tsukuba-hpcs/spack-packages)
- [Preliminary PMEM benchmark and evaluation](https://github.com/range3/pmembench)
- [Repository for evaluation on the Pegasus supercomputer used in the paper, including spack settings, benchmarks, job scripts, raw logs, and visualization scripts](https://github.com/tsukuba-hpcs/mpiio-pmembb)
