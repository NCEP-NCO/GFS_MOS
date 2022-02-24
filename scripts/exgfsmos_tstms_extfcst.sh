#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_tstms_extfcst.sh.ecf
#  Purpose: To run all steps necessary to create extended-range GFS MOS
#           fcsts for thunderstorms and severe weather.  This script
#           adds the extended projections to the tsvr random access
#           file created in the short-range job, exgfs_tsvrmos.
#           Note:  In the initial implementation, this job runs only
#           at 00Z.
#  Remarks:
#  HISTORY: Mar 16, 2005      - new job for GFS gridded MOS
#           Sep 13, 2005 RLC  - Added hard stop if short-range random
#                               access file isn't found.
#           Feb 27, 2006 RLC/KKG - Added 40-km extended-range TSTMS, and
#                                 1200 UTC job
#           Feb 29, 2008 RLC  - added 47km forecasts for AK
#           Oct 30, 2009 JCM  - removed old 48-km thunderstorm piece
#           Dec 03, 2012 EFE  - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Feb 10, 2016 SDS  - Configured for MPMD
#
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_tstms_extfcst
set -x

cd $DATA/tstms
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
#
#    THIS JOB USES THE RANDOM ACCESS FILES FIRST CREATED IN THE
#    EXECUTION OF EXGFS_TSVRMOS.  CHECK IF THE FILES 
#    MDL_GFSTSVR40.TXXZ AND MDL_GFSTSVRAK47.TXXZ EXIST IN COM/GFS.  
#    IF THEY DO, COPY THE FILE TO THE WORK SPACE.
#    IF THEY DO NOT EXIST, THE SCRIPT WILL ABORT.  EXGFS_EXTTSVRMOS
#    WILL NOT WORK UNLESS EXGFS_TSVRMOS HAS ALREADY RUN SUCCESSFULLY.
#
#######################################################################
#
#######################################################################
#  CREATE THE 40KM EXTENDED RANGE THUNDERSTORM FORECASTS
#  AT 0000 AND 1200 UTC CYCLES
#
#  THEN CREATE THE 47KM ALASKA THUNDERSTORMS AT 0000 AND 1200
#
#######################################################################

if [ ! -f $COMIN/mdl_gfstsvr40.$cycle ]
        then echo 'need successful run of gfsmos_tstms_fcst to run properly' >> $pgmout
        export err=1; err_chk
fi

cpreq $COMIN/mdl_gfstsvr40.$cycle .

#######################################################################
# COPY MODEL FILES TO TEMP SPACE
#######################################################################
cpreq $COMIN/mdl_gfspkd47.$cycle pkgfsraw.$DAT
cpreq $COMIN/mdl_gfsxpkd47.$cycle pkgfsxraw.$DAT

#######################################################################
#
# PROGRAM MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#  (U201)
#
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT23="pkgfsraw.$DAT"
export FORT24="pkgfsxraw.$DAT"
export FORT26="$FIXcode/mdl_tsvr40sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr40sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxtsvr40prd"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_constgrd40"
#   Output predictors
export FORT60="tsvrprdx40.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfsxpredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended

#
#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS - FOR TSVR
#    (U900/U700)
#
#######################################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT24="tsvrprdx40.$DAT"
export FORT26="$FIXcode/mdl_tsvr40sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr40sta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gfsxtsvr40km.07011015.$cycle"
export FORT31="$FIXgfs_mos/mdl_gfsxtsvr40km.10160315.$cycle"
export FORT32="$FIXgfs_mos/mdl_gfsxtsvr40km.03160630.$cycle"
#  Output random access raw forecast file below
export FORT49="mdl_gfstsvr40.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsxevaltsvr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  EQNEVAL ended

#######################################################################
#
#    PROGRAM FCSTPOST - POST-PROCESSES MOS FORECASTS - FOR TSVR
#    (U910/U710)
#
#######################################################################

echo MDLLOG: `date` - begin job FCSTPOST - POST PROCESS TSVR FORECASTS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXcode/mdl_tsvr40sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr40sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxposttsvr40.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
#  Input and Output random access raw and processed forecast file below
export FORT49="mdl_gfstsvr40.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfsposttsvr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_gfstsvr40.$cycle $COMOUT
fi

#######################################################################
#  Note:  This second set of rainit through fcstpost is for the 47 km
#         Alaska forecasts.  They will be stored in the file gfstsvrak47.
#         Copy that file from /com/gfs.
#######################################################################

if [ ! -f $COMIN/mdl_gfstsvrak47.$cycle ]
        then echo 'need successful run of gfsmos_tstms_fcst to run properly' >> $pgmout
        export err=1; err_chk
fi

cpfs $COMIN/mdl_gfstsvrak47.$cycle .

#
#######################################################################
#
# PROGRAM MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT23="pkgfsraw.$DAT"
export FORT24="pkgfsxraw.$DAT"
export FORT26="$FIXgfs_mos/mdl_tsvrak47sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvrak47sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxtsvrak47prd.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_constgrdak47"
export FORT60="tsvrprdxak47.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfsxpredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended

#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS - FOR TSVR
#
#######################################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT24="tsvrprdxak47.$DAT"
export FORT26="$FIXgfs_mos/mdl_tsvrak47sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvrak47sta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gfsxtsvrak47.05010930.$cycle"
export FORT31="$FIXgfs_mos/mdl_gfsxtsvrak47.10010430.$cycle"
export FORT49="mdl_gfstsvrak47.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsevaltsvrak47.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  EQNEVAL ended

#######################################################################
#
#    PROGRAM FCSTPOST - POST-PROCESSES MOS FORECASTS - FOR TSVR
#
#######################################################################

echo MDLLOG: `date` - begin job FCSTPOST - POST PROCESS TSVR FORECASTS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_tsvrak47sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvrak47sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxposttsvrak47.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT49="mdl_gfstsvrak47.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfsposttsvr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_gfstsvrak47.$cycle $COMOUT
fi

echo MDLLOG: `date` - Job exgfsmos_tstms_extfcst has ended.
#######################################################################
