# peanuts-playground

https://github.com/tsukuba-hpcs/peanuts-playground

## Getting Started
PEANUTSのお試し環境をDockerコンテナに準備しました。実際のPersitent memoryは利用できませんが、PEANUTSの動作を確認することができます。
docker composeを利用して、4つのコンテナからなる仮想的なクラスターを構築します。
コンテナ間は、OpenMPI-peanutsを使って、MPIが利用できます。

VSCodeとdevcontainer extensionを利用してテストを行っていますので、まずは以下の手順で環境を構築してください。
1. [VSCode](https://code.visualstudio.com/)をインストール
2. [Developing inside a Container](https://code.visualstudio.com/docs/devcontainers/containers)を参考にして、Dockerをインストール
3. [Remote Development](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack) extensionをインストール

次に、このリポジトリをクローンして、VSCodeで開き、devcontainerをビルドします。

```console
git clone --recursive git@github.com:tsukuba-hpcs/peanuts-playground.git
cd peanuts-playground
code .
```

Use the command palette to open the project in a container.  
`> Dev Containers: Rebuild and Reopen in Container`

コンテナが起動したら、以下のコマンドでPEANUTSをビルドします。
PEANTUSのインストールは、[spack](https://spack.io/)を利用しています。
後の可視化のために、Pipでpythonモジュールもインストールしています。
```console
# in the container

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

spack env create dev spack/envs/dev/spack.yaml
spack env activate dev
spack concretize -fU
spack install
```

## Run Benchmarks
spack installに成功すると、以下のツールがインストールされます。
- OpenMPI integrated with PEANUTS (mpirun)
- benchmarks
  - ior
  - rdbench
  - h5bench_write / h5bench_read

これらを用いて、PEANUTSの論文にあるベンチマークを実行することができます。
ただし、コンテナ環境では以下の制約があります。
- Persistent memoryは利用できませので、代わりに`/tmp/pseudo_pmem`ファイルを見せかけのPMEMデバイスとして利用しています。
- process per node PPN>1の場合、file-backed memoryをMPI_Win_createで登録に失敗するため、PPN=1でmpirunを実行してください

ベンチマークをコンテナ内で実行するためのスクリプトを用意しました。
- `src/ior.sh`
- `src/rdbench.sh`
- `src/h5bench.sh`

実行すると、結果が`raw/`ディレクトリに出力されます。

```console
cd src
./ior.sh
./rdbench.sh
./h5bench.sh
```


## Plot Results
`raw/`以下のログをパースしてグラフにするためのJupyter notebookを用意しました。
- `src/ior.ipynb`
- `src/rdbench.ipynb`
- `src/h5bench.ipynb`

実行に必要なpipモジュールは`.venv/`以下にインストールされています。
各jupyter notebookを開き、右上の`Select Kernel`から`.venv`を選択し、全体を実行してください。

ベンチマークの実行に失敗した場合は、壊れた結果ファイルが生成される場合があるので、削除してください。

## Install PEANUTS on a Real Cluster

PEANUTSの論文では、University of TsukubaのPegasusスーパーコンピュータを利用しましたが、
PegasusはArtifact Evaluationのためにアカウントを準備することができませんでした。
代わりに、我々の研究室が所有するchris9xクラスターを利用して、PEANUTSを実行する方法を説明します。

chris9xクラスターは、chris90, chris91の2ノードのクラスターで、
Intel Optane DCPMMの第２世代と、InfiniBand EDRが搭載されています。

以下の作業を、chris90にsshで接続して行ってください。
(申し訳ございませんが、NFSが貧弱なため、git cloneやビルドには時間がかかります)

```console
# checkout
git clone --recursive git@github.com:tsukuba-hpcs/peanuts-playground.git
cd peanuts-playground

# install python modules for visualization
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# prepare spack
source externals/spack/share/spack/setup-env.sh

# build PEANUTS and benckmarks and configuration tools with spack
spack repo add externals/spack-packages
spack env create peanuts spack/envs/peanuts/spack.yaml
spack env activate peanuts
spack concretize -fU
spack install

# prepare interleaved devdax PMEM (requires root privilege)
sudo env PATH=$PATH ndctl destroy-namespace all --force
sudo env PATH=$PATH ndctl create-namespace --mode=devdax
sudo chmod 666 /dev/dax0.0
```

実際には最後のDEVDAXの準備は、root権限で事前に行っています。

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

## Run Benchmarks on a real cluster

ベンチマークを実PMEMデバイスを持つchris9xクラスターで実行するためのスクリプトを用意しました。
- `src/ior-chris9x.sh`
- `src/rdbench-chris9x.sh`
- `src/h5bench-chris9x.sh`

実行前に、spackが有効になってることを確認してください。
```console
source externals/spack/share/spack/setup-env.sh
cd src
./ior-chris9x.sh
./rdbench-chris9x.sh
./h5bench-chris9x.sh
```

PEANUTSは、MPI_Init()の直後に自動的に`/dev/dax0.0`を仮想アドレス空間にマップし、
`MPI_Win_create()`によってPMEMをRDMA-capable NICに登録します。
mpirunのランタイムコマンドを通して、PEANUTSにパラメータを渡すことができますが、
上記のスクリプトでは設定済みです。詳しくは以下のコマンドで確認できます。


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



他のユーザーが`/dev/dax0.0`を使用している場合、同時に実行することができません。

IORは、論文中では様々なtransfer sizeで実行されていますが、スクリプトでは32KiBのtransfer sizeで実行しています。
他のtransfer sizeでの実行を試したい場合は、ior-chris9x.sh内の、xfer_size_list変数のコメントアウトを削除してください。


## Plot Results on a real cluster
結果の可視化は、chris9xクラスター上で行うことができます。
その場合は、VSCodeとRemote SSH extensionを利用して、chris90に接続してください。
もしくは、ログファイルをscpでローカルにコピーして、ローカルdevcontainer内で、Jupyter notebookを実行してください。

予備実験によって、chris9xクラスターのPMEMデバイス性能の限界を測定しています。 このベンチマークは、1ノードでのPMEMデバイスの並列I/O性能を測定しています。
[range3/pmembench benchmark result](https://github.com/range3/pmembench/blob/4db7408da4a5a5767c93657cc03cd933f3fac61c/eval/README.md)

このグラフの青の線が、chris9xのOptane DCPMM 200 series (第２世代)の結果です。
書き込みのピークは15 GiB/sですが、16スレッドでアクセスすると10 GiB/s程度に低下します。これはOptane DCPMM第２世代の特性です。
読み込みは16スレッド32 KiB transfer sizeで、42 GiB/s程度出ていることがわかります。

ネットワークの性能は、chris9xにはInfiniBand EDRが搭載されていますので、100 Gbps == 12.5 GB/s/nodeです。

iorを可視化して、32 KiB 2 nodeの性能が
- Write: 20 GiB/s,
- Remote Read: 25 GB/s == 23.3 GiB/s
- Local Read: 84 GiB/s

に近い性能が出ていれば成功です。

参考のために、raw-sample/ディレクトリにchris9xのベンチマーク結果をサンプルとして置いてあります。
src/ior.ipynb, src/rdbench.ipynb, src/h5bench.ipynbの初期状態は、このベンチマーク結果を可視化したものです。

# PEANUTS論文との差異
- Pegasus supercomputer vs Chris9x

|            | Pegasus                             | Chris9x                            |
| ---------- | ----------------------------------- | ---------------------------------- |
| PMEM       | Optane DCPMM 300 series (第３世代)  | Optane DCPMM 200 series (第２世代) |
| NETWORK    | InfiniBand HDR200                   | InfiniBand EDR                     |
| CPU        | Xeon Platinum 8468, 2.1GHz 48 cores | Xeon Gold 6326, 2.90GHz 16 cores   |
| Node count | 100                                 | 2                                  |

- RDBenchはアプリの制約上2ノードではweak scalingの評価ができなかったので、chris9xではstrong scalingでスクリプトを書いています。


# References
- [PEANUTS core libraies](https://github.com/tsukuba-hpcs/peanuts)
- [OpenMPI with PEANUTS](https://github.com/tsukuba-hpcs/ompi-peanuts)
- [Spack packages for installing PEANUTS](https://github.com/tsukuba-hpcs/spack-packages)
- [Preliminary PMEM benchmark and evaluation](https://github.com/range3/pmembench)
- [Repository for evaluation on the Pegasus supercomputer used in the paper, including spack settings, benchmarks, job scripts, raw logs, and visualization scripts](https://github.com/tsukuba-hpcs/mpiio-pmembb)
