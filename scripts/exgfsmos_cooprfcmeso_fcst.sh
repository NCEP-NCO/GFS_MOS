#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_cooprfcmeso_fcst.sh.ecf
#  Purpose: To run all steps necessary to create short range GFS 
#           MOS fcsts for the coop and RFC sites
#  Remarks: 
#  HISTORY: May  7, 2004      - new script 
#           Jan 21, 2005 RLC  - Added mesowest sites w/temp and wind
#                               to the script.  Changed some filenames
#           Mar 03, 2005 RLC  - Set up script to run in gridded MOS
#                               paradigm in parallel.  Now it only 
#                               runs through the post-processor.  The
#                               products and archiving will be done
#                               in a subsequent script. 
#           Dec 03, 2012 EFE  - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Jan 21, 2016 SDS  - Configured for MPMD
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_cooprfcmeso_fcst
set -x

cd $DATA/cooprfcmeso
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
# COPY MDL MODEL FILES FROM /COM TO TEMP SPACE
#######################################################################

  cpreq $COMIN/mdl_gfspkd47.$cycle gfspkd.$cycle

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
#
export pgm=mdl_racreate
. prep_step
export FORT50="mdl_gfscpmos.$cycle"
startmsg
$EXECcode/mdl_racreate < $PARMcode/mdl_u350.cn >> $pgmout 2>errfile
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
#
export pgm=mdl_rainit
. prep_step
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_cooprfcmnsta.lst"
export FORT27="$FIXgfs_mos/mdl_cooprfcmnsta.tbl"
export FORT49="mdl_gfscpmos.$cycle"
startmsg
$EXECcode/mdl_rainit < $PARMcode/mdl_u351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT ended 

#
#######################################################################
#
#    EXECUTION OF PROGRAM MOSPRED FOR MODEL DATA
#    MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT24="gfspkd.$cycle"
export FORT26="$FIXgfs_mos/mdl_cooprfcmnsta.lst"
export FORT27="$FIXgfs_mos/mdl_cooprfcmnsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfscpprd.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_constcooprfcmn"
export FORT60="gfscpmodel.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfspredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended 

#
#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS
#
#######################################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT24="gfscpmodel.$DAT"
export FORT26="$FIXgfs_mos/mdl_cooprfcmnsta.lst"
export FORT27="$FIXgfs_mos/mdl_cooprfcmnsta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gfscprfcmxmn.04010930.$cycle"
export FORT31="$FIXgfs_mos/mdl_gfscprfcmxmn.10010331.$cycle"
export FORT32="$FIXgfs_mos/mdl_gfscpsnow.09010831.$cycle"
export FORT33="$FIXgfs_mos/mdl_gfsmntd.04010930.$cycle"
export FORT34="$FIXgfs_mos/mdl_gfsmntd.10010331.$cycle"
export FORT37="$FIXgfs_mos/mdl_gfsmnmxmn.04010930.$cycle"
export FORT38="$FIXgfs_mos/mdl_gfsmnmxmn.10010331.$cycle"
export FORT35="$FIXgfs_mos/mdl_gfsmnwind.04010930.$cycle"
export FORT36="$FIXgfs_mos/mdl_gfsmnwind.10010331.$cycle"
export FORT49="mdl_gfscpmos.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfscpeval.cn.$cycle >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  EQNEVAL ended 

#######################################################################
#
#    PROGRAM FCSTPOST - POST-PROCESSES MOS FORECASTS
#
#######################################################################

echo MDLLOG: `date` - begin job FCSTPOST - POST PROCESS MOS FORECASTS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_cooprfcmnsta.lst"
export FORT27="$FIXgfs_mos/mdl_cooprfcmnsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfscppost.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT45="$FIXgfs_mos/mdl_constcooprfcmn"
export FORT47="$FIXgfs_mos/mdl_coopthreshold"
export FORT49="mdl_gfscpmos.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfspost.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended 

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_gfscpmos.$cycle $COMOUT
fi

echo MDLLOG: `date` - Job exgfsmos_cooprfcmeso_fcst has ended.
#######################################################################
