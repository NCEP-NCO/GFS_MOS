#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_goe_fcst.sh.ecf
#  Purpose: To run all steps necessary to create short range GFS-based
#           MOS fcsts for the generalized operator.  These forecasts
#           will be used as the inititialization for the gridded MOS
#           analysis.  This script runs all the steps to create the
#           forecasts.  Subsequent scripts will produce the products.
#           This script runs at 00 and 12Z.   
#  Remarks: 
#  HISTORY: Mar 03, 2005      - new job for GFS Gridded MOS
#           Jun 19, 2006      - took out wind goe, added cp of 201
#                               output to com for later u140
#           Jun 29, 2006      - expanded goes to full CONUS.  Removed
#                               snow equations for now.
#           Feb   , 2007      - added qpf, snow, clouds goes
#           Dec 03, 2012 EFE  - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Jan 21, 2016 SDS  - Configured for MPMD
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_goe_fcst
set -x

cd $DATA/goe
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
# COPY MODEL FILES TO TEMP SPACE -- this file is created in job
#    gfs_mos_prep.  Contains GFS data from 0 - 96 hours.
#######################################################################
cpreq $COMIN/mdl_gfspkd47.$cycle pkgfsraw.$DAT

#
#######################################################################
#
# PROGRAM RACREATE - MOS-2000 PROGRAM WHICH
#                   CREATES RANDOM ACCESS FILES; IN THIS CASE, THE
#                   CODE IS USED TO CREATE THE OPERATIONAL MOS
#                   FORECAST FILE.
#######################################################################
#
echo MDLLOG: `date` - begin job RACREATE - CREATE MOS FORECAST FILE
export pgm=mdl_racreate
. prep_step
export FORT50="mdl_goemos.$cycle"
startmsg
$EXECcode/mdl_racreate < $PARMgfs_mos/mdl_gmosu350.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RACREATE ended

#
#######################################################################
#
#  PROGRAM RAINIT - INITIALIZES RANDOM ACCESS MOS FORECAST
#                   FILE WITH STATION CALL LETTERS,
#                   ELEVATION, LATITUDE, AND LONGITUDE
#
#######################################################################
export pgm=mdl_rainit
. prep_step
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export FORT10="ncepdate"
export FORT27="$FIXgfs_mos/mdl_ndfdsta.tbl"
export FORT49="mdl_goemos.$cycle"
startmsg
$EXECcode/mdl_rainit < $PARMgfs_mos/mdl_gmosu351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT ended

cpreq $FIXgfs_mos/mdl_constndfdsta mdl_goemos.$cycle
#
#######################################################################
#
#  PROGRAM MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#
#######################################################################
echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT24="pkgfsraw.$DAT"
export FORT27="$FIXgfs_mos/mdl_ndfdsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsgoeprd.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_constndfdsta"
#export FORT44="$FIXgfs_mos/mdl_constndfdsta_ra_vis"
export FORT60="goemosmodel.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfsgmospredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended

#
#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS
#
#######################################################################
export IOBUF_PARAMS='*:size=4M:'

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT24="goemosmodel.$DAT"
export FORT27="$FIXgfs_mos/mdl_ndfdsta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
#export FORT42="$FIXcode/mdl_constndfdsta_ra_vis"
export FORT35="$FIXgfs_mos/mdl_gfsgoepopqpf.04010930.$cycle"
export FORT36="$FIXgfs_mos/mdl_gfsgoepopqpf.10010331.$cycle"
export FORT49="mdl_goemos.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsgmoseval.cn.$cycle >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  EQNEVAL ended 

#######################################################################
#
#    PROGRAM FCSTPOST - POST-PROCESSES MOS FORECASTS
#
#######################################################################
export IOBUF_PARAMS=''

echo MDLLOG: `date` - begin job FCSTPOST - POST PROCESS MOS FORECASTS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT27="$FIXgfs_mos/mdl_ndfdsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsgoepost.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT45="$FIXgfs_mos/mdl_constndfdtrimsta"
export FORT47="$FIXgfs_mos/mdl_goethreshold"
export FORT49="mdl_goemos.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gmospost.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended 

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_goemos.$cycle $COMOUT
  cpfs goemosmodel.$DAT $COMOUT/mdl_goemosmodel.$cycle
fi


echo MDLLOG: `date` - Job exgfsmos_goe_fcst has ended.
#######################################################################
