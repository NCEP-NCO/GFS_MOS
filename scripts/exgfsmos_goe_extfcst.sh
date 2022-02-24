#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_goe_extfcst.sh.ecf
#  Purpose: To run all steps necessary to create extended-range GFS-based
#           MOS fcsts for the generalized operator.  These forecasts
#           will be used as the inititialization for the gridded MOS
#           analysis.  This script runs all the steps to create the
#           forecasts.  Subsequent scripts will produce the products.
#           This script runs at 00 and 12Z.   
#  Remarks: 
#  HISTORY: Mar 17, 2005      - new job for GFS Gridded MOS
#           Jun 19, 2006      - took out wind goe, added cp of 201
#                               output to com for later u140
#           Jun 29, 2006      - expanded goes to full CONUS.  Removed
#                               snow equations for now.
#           Aug 03, 2006      - added check that short-range file
#                               exists
#           Feb   , 2007      - added qpf, snow, clouds goes
#           Dec 03, 2012 EFE  - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Feb 10, 2016 SDS  - Configured for MPMD
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_goe_extfcst
set -x

cd $DATA/goe
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
#
#    THIS JOB USES THE RANDOM ACCESS FILE FIRST CREATED IN THE
#    EXECUTION OF GFSMOS_GOE_FCST.  CHECK IF THE FILE MDL_GOEMOS.TXXZ
#    EXISTS IN COM/GFS.  IF IT DOES, COPY THE FILE TO THE WORK SPACE.
#    IF IT DOES NOT EXIST, THE SCRIPT WILL ABORT.  GFSMOS_GOE_EXTFCST
#    WILL NOT WORK UNLESS GFSMOS_GOE_FCST HAS ALREADY RUN SUCCESSFULLY.
#
#######################################################################
#
if [ ! -f $COMIN/mdl_goemos.$cycle ]
     then echo 'need successful run of exgfs_mos to run properly' >> $pgmout        
             export err=1;err_chk
fi

cpreq $COMIN/mdl_goemos.$cycle .


#######################################################################
# COPY MODEL FILES TO TEMP SPACE 
#######################################################################
cpreq $COMIN/mdl_gfspkd47.$cycle pkgfsraw.$DAT
cpreq $COMIN/mdl_gfsxpkd47.$cycle pkgfsxraw.$DAT

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
export FORT23="pkgfsraw.$DAT"
export FORT24="pkgfsxraw.$DAT"
export FORT27="$FIXgfs_mos/mdl_ndfdsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxgoeprd.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_constndfdsta"
export FORT60="goemosxmodel.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfsxgmospredmdl.cn >> $pgmout 2>errfile
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
export FORT24="goemosxmodel.$DAT"
export FORT27="$FIXgfs_mos/mdl_ndfdsta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT35="$FIXgfs_mos/mdl_gfsxgoepopqpf.04010930.$cycle"
export FORT36="$FIXgfs_mos/mdl_gfsxgoepopqpf.10010331.$cycle"
export FORT49="mdl_goemos.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsxgmoseval.cn.$cycle >> $pgmout 2>errfile
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
export FORT27="$FIXgfs_mos/mdl_ndfdsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxgoepost.$cycle"
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
  cpfs goemosxmodel.$DAT $COMOUT/mdl_goemosxmodel.$cycle
fi


echo MDLLOG: `date` - Job exgfsmos_goe_extfcst has ended.
#######################################################################
