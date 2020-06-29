#!/bin/bash -eux
#GITHUB_WORKSPACE=/Users/guang/tmp/koko

if [ '${INPUT_UPLOAD_URL}' ];then
  RELEASE_ASSETS_UPLOAD_URL=${INPUT_UPLOAD_URL}
else
  RELEASE_ASSETS_UPLOAD_URL=$(cat ${GITHUB_EVENT_PATH} | jq -r .release.upload_url)
  RELEASE_ASSETS_UPLOAD_URL=${RELEASE_ASSETS_UPLOAD_URL%\{?name,label\}}
fi
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

cd ${build_dir} && bash build.sh

# 准备打包
cd ${workspace}/release
for i in $(ls);do
  if [[ ! -d $i ]];then
    continue
  fi
  if [[ "${OS}" && "${ARCH}" ]];then
    tar_dirname=$i-${RELEASE_TAG:-"master"}-${OS}-${ARCH}
    mv $i ${tar_dirname}
  else
    tar_dirname=$i
  fi
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
    -H "Authorization: Bearer ${INPUT_GITHUB_TOKEN}" \
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
      -H "Authorization: Bearer ${INPUT_GITHUB_TOKEN}" \
      "${RELEASE_ASSETS_UPLOAD_URL}?name=${file}"
   return $?
}

# 打包完上传
for i in $(ls);do
  # 因为可能是md5已被上传了
  if [ ! -f $i ];then
    continue
  fi
  if [[ $i == *.tar.gz ]];then
    upload_zip $i && rm -f ${i}

    if [[ -f $i.md5 ]];then
      upload_octet $i.md5 && rm -f ${i}
    fi
  fi
done
