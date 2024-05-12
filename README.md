# peanuts-playground

## Getting Started
```console
git clone --recursive git@github.com:tsukuba-hpcs/peanuts-playground.git
cd peanuts-playground
code .
```

Open vscode and install the recommended extensions.
- [Remote Development](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack)

Use the command palette to open the project in a container.
`> Dev Containers: Rebuild and Reopen in Container`

```console
# in the container

spack env create dev spack/envs/dev/spack.yaml
spack env activate dev
```
