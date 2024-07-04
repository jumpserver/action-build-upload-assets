#!/bin/bash -xi
#GITHUB_WORKSPACE=

OS=${INPUT_OS-''}
ARCH=${INPUT_ARCH-''}
RELEASE_TAG=$(basename "${GITHUB_REF:-'master'}")
export VERSION=${RELEASE_TAG:-"master"}

function add_pkg() {
  pkg=$1
  command -v apk && apk add ${pkg} && return 0
  command -v yum && yum makecache fast && yum install -y ${pkg} && return 0
  command -v apt && apt-get update && apt-get install -y ${pkg} && return 0
}

if [[ $(uname) != 'Darwin' ]];then
  command -v bash || add_pkg bash
  command -v curl || add_pkg curl
  command -v jq || add_pkg jq
  command -v git || add_pkg git
  command -v tar || add_pkg tar
  command -v unzip || add_pkg unzip
fi

#INPUT_UPLOAD_URL='https://uploads.github.com/repos/ibuler/koko/releases/27862783/assets'
if [[ -n "${INPUT_UPLOAD_URL=''}" ]];then
  RELEASE_ASSETS_UPLOAD_URL=${INPUT_UPLOAD_URL}
else
  RELEASE_ASSETS_UPLOAD_URL=$(jq -r .release.upload_url < "${GITHUB_EVENT_PATH}")
fi
RELEASE_ASSETS_UPLOAD_URL=${RELEASE_ASSETS_UPLOAD_URL%\{?name,label\}}
#INPUT_GITHUB_TOKEN=

function get_md5() {
  file=$1
  if [[ "$(uname)" == "Darwin" ]];then
    echo $(md5 ${file} | awk '{ print $NF }')
  else
    echo $(md5sum ${file} | cut -d ' ' -f 1)
  fi
}

# First to build it
workspace=${GITHUB_WORKSPACE}
build_dir=''

git config --global --add safe.directory /github/workspace
git config --global --add safe.directory ${workspace}

if [[ -f ${workspace}/build.sh ]];then
  build_dir=${workspace}
fi

if [[ -z ${build_dir} && -f ${workspace}/utils/build.sh ]];then
  build_dir=${workspace}/utils
fi

if [[ -z ${build_dir} ]];then
  echo "No build script found at: PROJECT/build.sh"
  exit 10
fi

cd ${build_dir} && bash -xieu build.sh || exit 3

# 准备打包
cd ${workspace}/release || exit 5
for i in *;do
  if [[ ! -d $i ]];then
    continue
  fi
  if [[ "${OS}" && "${ARCH}" ]];then
    tar_dirname=$i-${VERSION}-${OS}-${ARCH}
  else
    tar_dirname=$i-${VERSION}
  fi
  mv ${i} ${tar_dirname}
  tar_filename=${tar_dirname}.tar.gz
  tar czvf ${tar_filename} ${tar_dirname}
  md5sum=$(get_md5 ${tar_filename})
  echo ${md5sum} > ${tar_filename}.md5 && rm -rf ${tar_dirname}
done

function upload_zip() {
  file=$1
  curl \
    --fail \
    -X POST \
    --data-binary @${file} \
    -H 'Content-Type: application/gzip' \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    "${RELEASE_ASSETS_UPLOAD_URL}?name=${file}"
    return $?
}

function upload_octet() {
  file=$1
   curl \
      --fail \
      -X POST \
      --data @${file} \
      -H 'Content-Type: application/octet-stream' \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      "${RELEASE_ASSETS_UPLOAD_URL}?name=${file}"
   return $?
}

if [[ -n "${ASSETS_UPLOAD_DISABLED-}" ]];then
  echo "禁用了上传，pass"
  exit 0
fi

# 打包完上传
for i in *;do
  # 因为可能是md5已被上传了
  if [[ ! -f $i || "$i" == *.md5 ]];then
    continue
  fi
  if [[ $i == *.tar.gz ]];then
    upload_zip $i || exit 3

    if [[ -f $i.md5 ]];then
      upload_octet $i.md5 || exit 4
    fi
  else
    upload_octet $i || echo 'Ignore file upload error';
  fi
done
