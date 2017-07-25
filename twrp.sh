#!/usr/bin/env bash
#
# TWRP compilation script
#
# Copyright (C) 2016-2017 Nathan Chancellor
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>


###########
#         #
#  USAGE  #
#         #
###########

# PURPOSE: Build F2FS TWRP for Angler/Shamu
# USAGE: $ bash twrp.sh -h


###############
#             #
#  FUNCTIONS  #
#             #
###############

# SOURCE OUR UNIVERSAL FUNCTIONS SCRIPT AND MAC CHECK
SCRIPT_DIR=$( cd $( dirname $( readlink -f "${BASH_SOURCE[0]}" ) ) && pwd )
source ${SCRIPT_DIR}/funcs.sh && macCheck

function help_menu() {
    echo -e ""
    echo -e ${BOLD}"OVERVIEW:${RST} Builds and pushes a Substratum APK\n"
    echo -e ${BOLD}"USAGE:${RST} bash ${0} <device> <options>\n"
    echo -e ${BOLD}"EXAMPLE:${RST} bash ${0} angler\n"
    echo -e ${BOLD}"REQUIRED PARAMETERS:${RST}"
    echo -e "   -d | --device:      angler | shamu\n"
    echo -e ${BOLD}"OPTIONAL PARAMETERS:${RST}"
    echo -e "   -s | --sync:        performs a repo sync before building\n"
    exit
}

################
#              #
#  PARAMETERS  #
#              #
################

while [[ $# -ge 1 ]]; do
    PARAMS+="${1} "

    case "${1}" in
        "-d"|"--device")
            shift
            DEVICE=${1} ;;

        "-h"|"--help")
            help_menu ;;

        "-p"|"--public")
            PUBLIC=true ;;

        "-s"|"--sync")
            SYNC=true ;;

        "-v"|"--version")
            shift
            export TW_DEVICE_VERSION=${1} ;;

        *)
            reportError "Invalid parameter detected!" ;;
    esac

    shift
done

# BUILD ANGLER IF DEVICE IS NOT SET
[[ -z ${DEVICE} ]] && DEVICE=angler


###############
#             #
#  VARIABLES  #
#             #
###############

# DIRECTORIES
SOURCE_DIR=${HOME}/TWRP-6.0
OUT_DIR=${SOURCE_DIR}/out/target/product/${DEVICE}
if [[ ${PUBLIC} = true ]]; then
    IMG_MOVE=${HOME}/Web/Downloads/TWRP/${DEVICE}
else
    IMG_MOVE=${HOME}/Web/me/TWRP/${DEVICE}
fi
VERSION=$( grep "TW_MAIN_VERSION_STR" ${SOURCE_DIR}/bootable/recovery/variables.h -m 1 | cut -d \" -f2 )-${TW_DEVICE_VERSION}

# FILE NAMES
COMP_FILE=recovery.img
UPLD_FILE=twrp-${VERSION}-${DEVICE}-f2fs-$( TZ=MST date +%Y%m%d ).img
FILE_FORMAT=twrp-*-${DEVICE}*
LOG_NAME=${LOGDIR}/Compilation/TWRP/twrp-${VERSION}-${DEVICE}-f2fs-$( TZ=MST date +%Y%m%d-%H%M ).log


##################
#                #
#  START SCRIPT  #
#                #
##################

clear && export EXPERIMENTAL_USE_JAVA8=true && START=$( TZ=MST date +%s )


#############
# REPO SYNC #
#############

cd ${SOURCE_DIR}

if [[ ${SYNC} = true ]]; then
    echoText "SYNCING LATEST SOURCES"

    repo sync --force-sync -j$( nproc --all )
fi


###########################
# SETUP BUILD ENVIRONMENT #
###########################

echoText "SETTING UP BUILD ENVIRONMENT"

# CHECK AND SEE IF WE ARE ON ARCH
# IF SO, ACTIVARE A VIRTUAL ENVIRONMENT FOR PROPER PYTHON SUPPORT
if [[ -f /etc/arch-release ]]; then
    virtualenv2 ${HOME}/venv && source ${HOME}/venv/bin/activate
fi

source build/envsetup.sh


##################
# PREPARE DEVICE #
##################

echoText "PREPARING $( echo ${DEVICE} | awk '{print toupper($0)}' )"

lunch omni_${DEVICE}-eng


############
# CLEAN UP #
############

echoText "CLEANING UP OUT DIRECTORY"

mka clobber


##################
# START BUILDING #
##################

echoText "MAKING TWRP"
NOW=$( TZ=MST date +"%Y-%m-%d-%S" )
time mka recoveryimage | tee -a ${LOG_NAME}


####################
# IF TWRP COMPILED #
####################

# THERE WILL BE A FILE IN THE OUT FOLDER IN THE ABOVE FORMAT
if [[ $( ls ${OUT_DIR}/${COMP_FILE} 2>/dev/null | wc -l ) != 0 ]]; then
    # MAKE BUILD RESULT STRING REFLECT SUCCESSFUL COMPILATION
    BUILD_RESULT_STRING="BUILD SUCCESSFUL"
    SUCCESS=true


    ##################
    # IMG_MOVE LOGIC #
    ##################

    # MAKE IMG_MOVE IF IT DOESN'T EXIST
    [[ ! -d "${IMG_MOVE}" ]] && mkdir -p "${IMG_MOVE}"/Old


    ####################
    # MOVING TWRP FILE #
    ####################

    mv "${IMG_MOVE}"/*.img* "${IMG_MOVE}"/Old
    mv "${OUT_DIR}"/${COMP_FILE} "${IMG_MOVE}"/${UPLD_FILE}


    ###################
    # GENERATE MD5SUM #
    ###################

    md5sum "${IMG_MOVE}"/${UPLD_FILE} > "${IMG_MOVE}"/${UPLD_FILE}.md5sum


###################
# IF BUILD FAILED #
###################

else
    BUILD_RESULT_STRING="BUILD FAILED"
    SUCCESS=false
fi



##############
# SCRIPT END #
##############

# DEACTIVATE VIRTUALENV IF WE ARE ON ARCH
if [[ -f /etc/arch-release ]]; then
    deactivate && rm -rf ${HOME}/venv
fi

END=$( TZ=MST date +%s )
echoText "${BUILD_RESULT_STRING}!"


######################
# ENDING INFORMATION #
######################

# IF THE BUILD WAS SUCCESSFUL, PRINT FILE LOCATION AND SIZE
if [[ ${SUCCESS} = true ]]; then
    echo -e ${RED}"FILE LOCATION: $( ls "${IMG_MOVE}"/${UPLD_FILE} )"
    echo -e "SIZE: $( du -h "${IMG_MOVE}"/${UPLD_FILE} | awk '{print $1}' )"${RST}
fi

# PRINT THE TIME THE SCRIPT FINISHED
# AND HOW LONG IT TOOK REGARDLESS OF SUCCESS
echo -e ${RED}"TIME FINISHED: $( TZ=MST date +%D\ %r | awk '{print toupper($0)}' )"
echo -e ${RED}"DURATION: $( format_time ${END} ${START} )"${RST}; newLine


##################
# LOG GENERATION #
##################

# DATE: BASH_SOURCE (PARAMETERS)
echo -e "\n$( TZ=MST date +"%m/%d/%Y %H:%M:%S" ): ${BASH_SOURCE} ${DEVICE}" >> ${LOG}

# BUILD <SUCCESSFUL|FAILED> IN # MINUTES AND # SECONDS
echo -e "${BUILD_RESULT_STRING} IN $( format_time ${END} ${START} )" >> ${LOG}

# ONLY ADD A LINE ABOUT FILE LOCATION IF SCRIPT COMPLETED SUCCESSFULLY
if [[ ${SUCCESS} = true ]]; then
    # FILE LOCATION: <PATH>
    echo -e "FILE LOCATION: $( ls "${IMG_MOVE}"/${UPLD_FILE} )" >> ${LOG}
fi


########################
# ALERT FOR SCRIPT END #
########################

echo -e "\a" && unset TW_DEVICE_VERSION && cd ${HOME}
