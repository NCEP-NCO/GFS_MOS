#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_cooprfcmeso_extfcst.sh.ecf
#  Purpose: To run all steps necessary to create extended-range GFS
#           MOS fcsts for the coop and RFC sites.  This job runs at
#           00 and 12z.
#  Remarks:
#  HISTORY: May  7, 2004      - new script
#           Jan 21, 2005 RLC  - Added mesowest sites w/temp and wind
#                               to the script.  Changed some filenames
#           Mar 03, 2005 RLC  - Set up script to run in gridded MOS
#                               paradigm in parallel.  Now it only
#                               runs through the post-processor.  The
#                               products and archiving will be done
#                               in a subsequent script.
#           Sep 13, 2005 RLC  - Added hard stop if short-range random
#                               access file isn't found.
#           Dec 03, 2012 EFE  - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Feb 10, 2016 SDS  - Configured for MPMD
#
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_cooprfcmeso_extfcst
set -x

cd $DATA/cooprfcmeso
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#
#######################################################################
#
#    THIS JOB USES THE RANDOM ACCESS FILES FIRST CREATED IN THE
#    EXECUTION OF EXGFS_COOPMOS.  CHECK IF THE FILE MDL_GFSCPMOS.TXXZ
#    EXISTS IN COM/GFS.  IF IT DOES, COPY THE FILE TO THE WORK SPACE.
#    IF IT DOES NOT THE SCRIPT WILL ABORT.  EXGFS_EXTCOOPMOS WILL
#    NOT WORK UNLESS EXGFS_COOPMOS HAS ALREADY RUN SUCCESSFULLY.
#
#######################################################################
#
if [ ! -f $COMIN/mdl_gfscpmos.$cycle ]
        then echo 'need successful run of gfsmos_cooprfcmeso_fcst to run properly' >> $pgmout
        export err=1;err_chk
fi

cpreq $COMIN/mdl_gfscpmos.$cycle .

#######################################################################
# COPY MDL MODEL FILES FROM /COM TO TEMP SPACE
#######################################################################

  cpreq $COMIN/mdl_gfspkd47.$cycle gfspkd.$cycle
  cpreq $COMIN/mdl_gfsxpkd47.$cycle gfsxpkd.$cycle
  cpreq $COMIN/mdl_gfsxpkd47.raw.$cycle gfsxpkd.raw.$cycle
  cpreq $COMIN/mdl_gfsxpkd47.raw.$cycle gfsxpkd.raw.$cycle

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
export FORT23="gfspkd.$cycle"
export FORT24="gfsxpkd.raw.$cycle"
export FORT26="$FIXgfs_mos/mdl_cooprfcmnsta.lst"
export FORT27="$FIXgfs_mos/mdl_cooprfcmnsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxcpprd.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_constcooprfcmn"
export FORT60="gfsxcpmodel.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfsxpredmdl.cn >> $pgmout 2>errfile
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
export FORT24="gfsxcpmodel.$DAT"
export FORT26="$FIXgfs_mos/mdl_cooprfcmnsta.lst"
export FORT27="$FIXgfs_mos/mdl_cooprfcmnsta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gfsxcprfcmxmn.04010930.$cycle"
export FORT31="$FIXgfs_mos/mdl_gfsxcprfcmxmn.10010331.$cycle"
export FORT32="$FIXgfs_mos/mdl_gfsxcpsnow.09010831.$cycle"
export FORT33="$FIXgfs_mos/mdl_gfsxmntd.04010930.$cycle"
export FORT34="$FIXgfs_mos/mdl_gfsxmntd.10010331.$cycle"
export FORT37="$FIXgfs_mos/mdl_gfsxmnmxmn.04010930.$cycle"
export FORT38="$FIXgfs_mos/mdl_gfsxmnmxmn.10010331.$cycle"
export FORT35="$FIXgfs_mos/mdl_gfsxmnwind.04010930.$cycle"
export FORT36="$FIXgfs_mos/mdl_gfsxmnwind.10010331.$cycle"
export FORT49="mdl_gfscpmos.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsxcpeval.cn.$cycle >> $pgmout 2>errfile
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
export FORT28="$FIXgfs_mos/mdl_gfsxcppost.$cycle"
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
  # FOR DEBUG -- REMOVE AFTER RESOLVED
  cpfs gfsxcpmodel.$DAT $COMOUT
fi

echo MDLLOG: `date` - Job exgfsmos_cooprfcmeso_extfcst has ended.
#######################################################################
