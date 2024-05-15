# peanuts-playground

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
