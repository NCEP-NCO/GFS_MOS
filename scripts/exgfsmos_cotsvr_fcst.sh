#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_cotsvr_prdgen.sh
#  Purpose: To run all steps necessary to create GFS-based gridded 
#           MOS unconditional severe thunderstorm fcsts on the CONUS
#           2.5 km NDFD Grid.
#
#  Remarks: None
#
#  HISTORY: 2012-04-30  Huntemann  New job for CONUS 2.5 km Gridded
#                                  MOS unconditional severe thunderstorms.
#                                  Adapted from 2.5 km
#                                  Gridded MOS prdgen scripts.
#           2012-05-31  Huntemann  Operationalized.  No longer linking
#                                  to we21ps directories.
#           2012-11-15  Huntemann  Adapted to run on Intel WCOSS.
#           2013-04-03  Huntemann  Added check for model data. This
#                                  script will sleep up to 2 hours if
#                                  model data is not present.
#           2013-11-07  Huntemann  Adapted for operations.
#           2013-12-04  Scallion   Removed sleep. Copy input file into
#                                  working (DATA) directory.
#           2016-01-21  Scallion   Configured for MPMD
#######################################################################
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
set -x

echo MDLLOG: `date` - Begin job $0

cd $DATA/cotsvr
cpreq $DATA/ncepdate .

#######################################################################
#  COPY THE GFS MODEL DATA FROM COM
#######################################################################
cpreq $COMIN/mdl_gfspkd47.$cycle .

#
#######################################################################
#
# PROGRAM MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#                   ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#  (U201)
#######################################################################
#
echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
startmsg
export FORT10="ncepdate"
export FORT24="mdl_gfspkd47.$cycle"
export FORT26="$FIXgfs_mos/mdl_tsvr80sta.lst.sort_wx"
export FORT27="$FIXgfs_mos/mdl_tsvr80sta.tbl.sort_wx"
export FORT28="$FIXgfs_mos/mdl_gfstsvr80prd"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_constgrd80"
export FORT60="preds.$PDY${cyc}"
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfspredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended 
#
#######################################################################
#
# PROGRAM RACREATE - MOS-2000 PROGRAM WHICH
#                    CREATES RANDOM ACCESS FILES; IN THIS CASE, THE
#                    CODE IS USED TO CREATE THE OPERATIONAL MOS
#                    FORECAST FILE.
#  (U350)
#######################################################################
#
echo MDLLOG: `date` - begin job RACREATE - CREATE MOS FORECAST FILE
export pgm=mdl_racreate
. prep_step
startmsg
export FORT50="mdl_gfscsvr80_ra.$PDY$cyc"
$EXECcode/mdl_racreate < $PARMcode/mdl_u350.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RACREATE ended
#
#######################################################################
#
# PROGRAM RAINIT - INITIALIZES 80km TSVR RANDOM ACCESS FORECAST FILE
#  (U351)
#######################################################################
#
export pgm=mdl_rainit
. prep_step
startmsg
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_tsvr80sta.lst.sort_wx"
export FORT27="$FIXgfs_mos/mdl_tsvr80sta.tbl.sort_wx"
export FORT49="mdl_gfscsvr80_ra.$PDY$cyc"
$EXECcode/mdl_rainit < $PARMcode/mdl_u351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT ended
#
#######################################################################
#
# PROGRAM EQNEVAL - CALCULATES MOS FORECASTS - FOR 80km TSVR
#  (U900/U700)
#######################################################################
#
echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
startmsg
export FORT10="ncepdate"
export FORT24="preds.$PDY$cyc"
export FORT26="$FIXgfs_mos/mdl_tsvr80sta.lst.sort_wx"
export FORT27="$FIXgfs_mos/mdl_tsvr80sta.tbl.sort_wx"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gfstsvr80km.07011015.$cycle"
export FORT31="$FIXgfs_mos/mdl_gfstsvr80km.10160315.$cycle"
export FORT32="$FIXgfs_mos/mdl_gfstsvr80km.03160630.$cycle"
export FORT49="mdl_gfscsvr80_ra.$PDY$cyc"
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsevaltsvr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  EQNEVAL ended 
#
#######################################################################
#
# PROGRAM FCSTPOST - POST-PROCESSES MOS FORECASTS - FOR TSVR
#  (U910/U710)
#######################################################################
#
echo MDLLOG: `date` - begin job FCSTPOST - POST PROCESS TSVR FORECASTS
export pgm=mdl_fcstpost
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_tsvr80sta.lst.sort_wx"
export FORT27="$FIXgfs_mos/mdl_tsvr80sta.tbl.sort_wx"
export FORT28="$FIXgfs_mos/mdl_gfsposttsvr80.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT49="mdl_gfscsvr80_ra.$PDY$cyc"
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfsposttsvr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended 
#
#######################################################################
#
# PROGRAM GRANALYSIS - ANALYZE SVR FORECASTS TO CONUS 2.5KM GRID
#  (U155)
#######################################################################
#
echo MDLLOG: `date` - begin job GRANALYSIS
export pgm=mdl_granalysis_co
. prep_step
startmsg
export FORT10="ncepdate"
export FORT20="$FIXgfs_mos/mdl_gmoscobogusfile.usvr"
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_gmos2p5"
export FORT49="mdl_gfscsvr80_ra.$PDY$cyc"
export FORT31="mdl_gfstsvr_grsq.$PDY$cyc"
export FORT26="$FIXgfs_mos/mdl_tsvr80sta.lst.sort_wx"
export FORT27="$FIXgfs_mos/mdl_tsvr80sta.tbl.u155_wx"
export FORT38="$FIXgfs_mos/mdl_gfstsvrgranlids"
export FORT51="$FIXgfs_mos/mdl_u405ausvr03cocn"
export FORT52="$FIXgfs_mos/mdl_u405ausvr12cocn"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
$EXECcode/mdl_granalysis_co < $PARMgfs_mos/mdl_granalysis_cotsvr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRANALYSIS ended
#
########################################################################
#
# Copy data to COMOUT
cpfs mdl_gfstsvr_grsq.$PDY$cyc $COMOUT/mdl_gfstsvr_grsq.$cycle

echo MDLLOG: `date` - End job $0

exit
