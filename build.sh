#!/bin/bash -eux
#GITHUB_WORKSPACE=/Users/guang/tmp/koko

OS=${INPUT_OS-''}
ARCH=${INPUT_ARCH-''}
RELEASE_TAG=$(basename "${GITHUB_REF}")
export VERSION=${RELEASE_TAG:-"master"}
if [[ -n "${INPUT_UPLOAD_URL}" ]];then
  RELEASE_ASSETS_UPLOAD_URL=${INPUT_UPLOAD_URL}
else
  RELEASE_ASSETS_UPLOAD_URL=$(jq -r .release.upload_url < "${GITHUB_EVENT_PATH}")
fi
RELEASE_ASSETS_UPLOAD_URL=${RELEASE_ASSETS_UPLOAD_URL%\{?name,label\}}
#RELEASE_ASSETS_UPLOAD_URL='https://uploads.github.com/repos/ibuler/koko/releases/27862783/assets'
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

cd ${build_dir} && bash -xi build.sh

# 准备打包
cd ${workspace}/release
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

# 打包完上传
for i in *;do
  # 因为可能是md5已被上传了
  if [ ! -f $i ];then
    continue
  fi
  if [[ $i == *.tar.gz ]];then
    upload_zip $i && rm -f ${i} || exit 3

    if [[ -f $i.md5 ]];then
      upload_octet $i.md5 && rm -f ${i}.md5 || exit 4
    fi
  else
    upload_octet $i || echo 'Ignore file upload error'; rm -f ${i}
  fi
done
