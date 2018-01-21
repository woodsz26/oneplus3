#!/bin/bash

# Bash colors
CL_GRN='\033[01;32m'
CL_BOLD="\033[1m"
CL_INV="\033[7m"
CL_RED="\033[01;31m"
CL_RST="\033[0m"
CL_YLW="\033[01;33m"
CL_BLUE="\033[01;34m"


# Resources
THREAD="-j$(nproc --all)"
DEFCONFIG="oneplus3_defconfig"
KERNEL="Image.gz-dtb"

# Caesium Kernel Details
KERNEL_NAME="Caesium"
INCREMENTAL_VERSION="BrokenBerries"
export LOCALVERSION=-${INCREMENTAL_VERSION}
GIT_HASH=$(git rev-parse --short HEAD)
DEVICE="oneplus3"
FINAL_VER="${KERNEL_NAME}-${DEVICE}-${INCREMENTAL_VERSION}"

# Vars
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER=MSF
export KBUILD_BUILD_HOST=jarvisbox

# Paths
WORKING_DIR=$(pwd)
ANYKERNEL_DIR="${WORKING_DIR}/../AnyKernel2"
TOOLCHAIN_DIR="${WORKING_DIR}/../toolchains/aarch64-linux-gnu/"
REPACK_DIR="${ANYKERNEL_DIR}"
OUT_DIR="${WORKING_DIR}/out/"
ZIP_MOVE="${WORKING_DIR}/zips/"
MAKE="make O=${OUT_DIR}"

## Functions
# Prints a formatted header to let the user know what's being done
function echoText {
    echo -e ${CL_RED}
    echo -e ${CL_BOLD}
    echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
    echo -e "==  ${1}  =="
    echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
    echo -e ${CL_RST}
}

# Prints an error in bold red
function reportError {
    echo -e ""
    echo -e ${CL_RED}"${1}"${CL_RST}
    if [[ -z ${2} ]]; then
        echo -e ""
    fi
    exit 1
}

# Prints a warning in bold yellow
function reportWarning {
    echo -e ""
    echo -e ${CL_YLW}"${1}"${CL_RST}
    if [[ -z ${2} ]]; then
        echo -e ""
    fi
}

# Prints the success banner
function reportSuccess {
    echo -e ${CL_GRN}
    echo -e ${CL_BOLD}
    echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
    echo -e "==  ${1}  =="
    echo -e "====$( for i in $( seq ${#1} ); do echo -e "=\c"; done )===="
    echo -e ${CL_RST}
}

function check_toolchain() {

    export TC="$(find ${TOOLCHAIN_DIR}/bin -type f -name *-gcc)";

        if [[ -f "${TC}" ]]; then
                export CROSS_COMPILE="$(command -v ccache) ${TOOLCHAIN_DIR}/bin/$(echo ${TC} | awk -F '/' '{print $NF'} | sed -e 's/gcc//')";
                echoText "$Using toolchain: $(${CROSS_COMPILE}gcc --version | head -1)"
        else
                reportError "No suitable toolchain found in ${TOOLCHAIN_DIR}";
        fi
}

function make_kernel {
  make_defconfig
  if [ ${MODULE} ]; then
      if [ ${VERBOSE} ]; then
          ${MAKE} ${MODULE} ${THREAD}
      else
          ${MAKE} ${MODULE} ${THREAD} |& ag "error:|warning"
      fi
  else
      if [ ${VERBOSE} ]; then
          ${MAKE} ${KERNEL} ${THREAD}
      else
          ${MAKE} ${KERNEL} ${THREAD} |& ag "error:|warning"
      fi
  fi
  BUILT_KERNEL=out/arch/${ARCH}/boot/${KERNEL}
  [ -f "${BUILT_KERNEL}" ] && cp -r ${BUILT_KERNEL} ${REPACK_DIR} && return 0 || reportError "Kernel compilation failed"
}

function make_defconfig {
  [ ${CLEAN} ] && rm -rf ${OUT_DIR}
  ${MAKE} ${DEFCONFIG} ${THREAD} 1>/dev/null 2>/dev/null
  ${MAKE} savedefconfig ${THREAD} 1>/dev/null 2>/dev/null
  [ ${REGEN_DEFCONFIG} ] && cp ${OUT_DIR}/defconfig arch/${ARCH}/configs/${DEFCONFIG} && echoText "Regenerated defconfig successfully" && exit 1
}
function make_zip {
  cd ${REPACK_DIR}
  rm *.zip 2>/dev/null
  [[ ${TEST_BUILD} ]] && FINAL_VER=${FINAL_VER}-$(date +"%Y%m%d"-"%H%M%S")-${GIT_HASH}
  zip -r ${FINAL_VER}.zip * -x ".git/*" "README.md" ".gitignore" "*.zip" 1>/dev/null 2>/dev/null
  mkdir -p ${ZIP_MOVE}
  cp  ${FINAL_VER}.zip ${ZIP_MOVE}/
  cd ${WORKING_DIR}
}

while getopts ":cbrm:t" opt; do
  case $opt in
    c)
      echoText " Building clean " >&2
      CLEAN=true
      ;;
    b)
      echoText " Building ZIP only " >&2
      ONLY_ZIP=true
      ;;
    r)
      echoText " Regenerating defconfig " >&2
      REGEN_DEFCONFIG=true
      ;;
    t)
      echoText " Setting test build parameters" >&2
      TEST_BUILD=true
      export LOCALVERSION="-${INCREMENTAL_VERSION}-${GIT_HASH}"
      ;;
    m)
      MODULE=${OPTARG}
      [[ ${MODULE} == */ ]] || MODULE=${MODULE}/
      if [[ ! "$(ls ${MODULE}Kconfig*  2>/dev/null)" ]]; then
          reportError "Invalid module specified - ${MODULE}"
          return 1
      fi
      echoText "Building module ${MODULE}"
      ;;
    \?)
      reportWarning "Invalid option: -${OPTARG}" >&2
      ;;
  esac
done

DATE_START=$(date +"%s")

# Make
check_toolchain
if [ ${ONLY_ZIP} ]; then
  make_zip
else
  make_kernel
  make_zip
fi

DATE_END=$(date +"%s")
DIFF=$((${DATE_END} - ${DATE_START}))
reportSuccess ${FINAL_VER}.zip

reportWarning "Time: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."