# 构建和上传 release assets

这个 action 是用来构建代码，并上传到release的

## 约定条件

项目中有 build.sh 或者 utils/build.sh, 并且可执行, 默认是在 centos:7 docker中运行构建，构建完成后需要放置到 项目 release 中

更多查看 : https://github.com/ibuler/koko/tree/master/.github/workflows

## Inputs

### `os`

如果构建区分os，则需要提供，主要用来生成 tar.gz时，打包成 NAME-VERSION-OS-ARCH.tar.gz


### `arch`

如果构建区分arch，则需要提供，主要用来生成 tar.gz时，打包成 NAME-VERSION-OS-ARCH.tar.gz


### `upload_url`

上传需要的release upload url, 如果没有提供，则尝试从 release event中获取

## Env
### GITHUB_TOKEN

### ASSETS_UPLOAD_DISABLED
不再上传

## Example usage

```yaml
on:
  push:
    # Sequence of patterns matched against refs/tags
    tags:
      - 'v*' # Push events to matching v*, i.e. v1.0, v20.15.10

name: Create Release And Upload assets

jobs:
  create-realese:
    name: Create Release
    runs-on: ubuntu-latest
    outputs:
      upload_url: ${{ steps.create_release.outputs.upload_url }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v2
      - name: Create Release
        id: create_release
        uses: release-drafter/release-drafter@v5
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          config-name: release-config.yml

  build-and-release:
    needs: create-realese
    name: Build and Release Matrix
    runs-on: ubuntu-latest
    strategy:
      matrix:
        os: [linux, darwin]
        arch: [amd64]
    steps:
      - uses: actions/checkout@v2
      - name: Build it and upload
        uses: ibuler/action-build-upload@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          os: ${{ matrix.os }}
          arch: ${{ matrix.arch }}
          upload_url: ${{ needs.create-realese.outputs.upload_url }}

```
