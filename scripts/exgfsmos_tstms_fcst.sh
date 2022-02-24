#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_tstms_fcst.sh.ecf
#  Purpose: To run all steps necessary to create short range GFS MOS 
#           fcsts for thunderstorms and severe weather.  This script
#           creates one set of forecasts on a 40km grid, 80-km and then
#           another on a 20km grid.  Then it creates forecasts for AK
#           on a 47km grid.
#  Remarks: 
#  HISTORY: Mar 10, 2005      - new job for GFS gridded MOS
#           Feb 27, 2006      - new job for GFS 40-km tstms, gridded MOS
#           Feb 29, 2008      - added 47km forecasts for AK
#           Oct 30, 2009      - removed "old" 48km tstorm/csvr; added
#                               80km tstorm/csvr.
#           Dec 16, 2011      - added 20km convection for CONUS
#           Jan 09, 2012  SDS - Modified for crisis RFC in response to
#                               00z 12/25/11 production failure of
#                               the NMM-MOS. The script has been 
#                               updated to use the 80km station list
#                               for the mospred TSVR steps.
#           Jun 12, 2012   PS - Replaced 3h 20-km tstms with new
#                               2h 20-km tstms (for LAMP input).
#           Dec 03, 2012  EFE - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Jan 21, 2016  SDS - Configured for MPMD
#
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_tstms_fcst
set -x

cd $DATA/tstms
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
# COPY MODEL FILES TO TEMP SPACE
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
#
export pgm=mdl_racreate
. prep_step
export FORT50="mdl_gfstsvr40.$cycle"
startmsg
$EXECcode/mdl_racreate < $PARMcode/mdl_u350.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RACREATE ended 

######################################################################
#  now copy the random access file to a 20km, 80km and an AK 47 for
#  tsvr and a 20km one for conv
######################################################################
cp mdl_gfstsvr40.$cycle mdl_gfstsvr20.$cycle
cp mdl_gfstsvr40.$cycle mdl_gfstsvr80.$cycle
cp mdl_gfstsvr40.$cycle mdl_gfstsvrak47.$cycle
cp mdl_gfstsvr40.$cycle mdl_gfsconv20.$cycle

#######################################################################
#  Note:  This first set of rainit through fcstpost is for the 40 km
#         forecasts.  They will be stored in the file gfstsvr40
#######################################################################

#######################################################################
#
#  PROGRAM RAINIT - INITIALIZES 40km TSVR RANDOM ACCESS FORECAST FILE
#  (U351)
#######################################################################
#
export pgm=mdl_rainit
. prep_step
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export FORT10="ncepdate"
export FORT26="$FIXcode/mdl_tsvr40sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr40sta.tbl"
export FORT49="mdl_gfstsvr40.$cycle"
startmsg
$EXECcode/mdl_rainit < $PARMcode/mdl_u351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT for TSVR ended 

#######################################################################
#
# PROGRAM MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#  (U201)
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT24="pkgfsraw.$DAT"
export FORT26="$FIXcode/mdl_tsvr40sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr40sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfstsvr40prd"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_constgrd40"
#  Output file follows
export FORT60="tsvrprd40.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfspredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended 

#
#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS - FOR 40km TSVR
#    (U900/U700)
#
#######################################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT24="tsvrprd40.$DAT"
export FORT26="$FIXcode/mdl_tsvr40sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr40sta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gfstsvr40km.07011015.$cycle"
export FORT31="$FIXgfs_mos/mdl_gfstsvr40km.10160315.$cycle"
export FORT32="$FIXgfs_mos/mdl_gfstsvr40km.03160630.$cycle"
#  Output random access file below containing raw forecasts
export FORT49="mdl_gfstsvr40.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsevaltsvr.cn >> $pgmout 2>errfile
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
export FORT28="$FIXgfs_mos/mdl_gfsposttsvr40.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
#  Input and Output random access file containing raw and processed forecasts
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

#######################################################################
#  Note:  This second set of rainit through fcstpost is for the 80 km
#         forecasts.  They will be stored in the file gfstsvr80
#######################################################################

#
#######################################################################
#
#  PROGRAM RAINIT - INITIALIZES 80km TSVR RANDOM ACCESS FORECAST FILE
#  (U351)
#######################################################################
#
export pgm=mdl_rainit
. prep_step
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_tsvr80sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr80sta.tbl"
export FORT49="mdl_gfstsvr80.$cycle"
startmsg
$EXECcode/mdl_rainit < $PARMcode/mdl_u351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT for TSVR ended 

#######################################################################
#
# PROGRAM MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#  (U201)
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT24="pkgfsraw.$DAT"
export FORT26="$FIXcode/mdl_tsvr80sta_trim.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr80sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfstsvr80prd"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_constgrd80"
#  Output file follows
export FORT60="tsvrprd80.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfspredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended 

#
#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS - FOR 80km TSVR
#    (U900/U700)
#
#######################################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT24="tsvrprd80.$DAT"
export FORT26="$FIXgfs_mos/mdl_tsvr80sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr80sta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gfstsvr80km.07011015.$cycle"
export FORT31="$FIXgfs_mos/mdl_gfstsvr80km.10160315.$cycle"
export FORT32="$FIXgfs_mos/mdl_gfstsvr80km.03160630.$cycle"
#  Output random access file below containing raw forecasts
export FORT49="mdl_gfstsvr80.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsevaltsvr.cn >> $pgmout 2>errfile
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
export FORT26="$FIXgfs_mos/mdl_tsvr80sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr80sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsposttsvr80.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
#  Input and Output random access file containing raw and processed forecasts
export FORT49="mdl_gfstsvr80.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfsposttsvr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended 

#######################################################################
# COPY FILES TO COM 
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_gfstsvr80.$cycle $COMOUT
fi
#######################################################################
#
#######################################################################
#  Note:  This third set of rainit through fcstpost is for the 20 km
#         forecasts.  They will be stored in the file gfstsvr20
#######################################################################
#
#######################################################################
#
#  PROGRAM RAINIT - INITIALIZES 20KM TSVR RANDOM ACCESS FORECAST FILE
#
#######################################################################
#
export pgm=mdl_rainit
. prep_step
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_tsvr20sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr20sta.tbl"
export FORT49="mdl_gfstsvr20.$cycle"
startmsg
$EXECcode/mdl_rainit < $PARMcode/mdl_u351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT for TSVR ended 

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
export FORT24="pkgfsraw.$DAT"
export FORT26="$FIXgfs_mos/mdl_tsvr20sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr20sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfstsvr20prd"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_constgrd20"
export FORT60="tsvrprd20.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfspredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended 

#
#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS - FOR TSVR
#
#######################################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT24="tsvrprd20.$DAT"
export FORT26="$FIXgfs_mos/mdl_tsvr20sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr20sta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gfstsvr20km.07011015.$cycle"
export FORT31="$FIXgfs_mos/mdl_gfstsvr20km.10160315.$cycle"
export FORT32="$FIXgfs_mos/mdl_gfstsvr20km.03160630.$cycle"
export FORT49="mdl_gfstsvr20.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsevaltsvr.cn >> $pgmout 2>errfile
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
export FORT26="$FIXgfs_mos/mdl_tsvr20sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr20sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsposttsvr20.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT49="mdl_gfstsvr20.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfsposttsvr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended 

#######################################################################
# COPY FILES TO COM 
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_gfstsvr20.$cycle $COMOUT
fi

#######################################################################
#  Note:  This fourth set of rainit through fcstpost is for the 47 km
#         Alaska forecasts.  They will be stored in the file gfstsvrak47
#######################################################################
#
#######################################################################
#
#  PROGRAM RAINIT - INITIALIZES 47KM TSVR RANDOM ACCESS FORECAST FILE
#
#######################################################################
#
export pgm=mdl_rainit
. prep_step
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_tsvrak47sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvrak47sta.tbl"
export FORT49="mdl_gfstsvrak47.$cycle"
startmsg
$EXECcode/mdl_rainit < $PARMcode/mdl_u351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT for TSVR ended 

#######################################################################
#
# PROGRAM MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#   NOTE:  THIS EXECUTION DOESN'T USE UNIT 44, IT'S HERE SO WE CAN USE
#          THE SAME CN FILE AS OTHER RUNS
#
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT24="pkgfsraw.$DAT"
export FORT26="$FIXgfs_mos/mdl_tsvrak47sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvrak47sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfstsvrak47prd.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_constgrdak47"
export FORT60="tsvrprdak47.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfspredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended 

#
#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS - FOR TSVR
#
#######################################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT24="tsvrprdak47.$DAT"
export FORT26="$FIXgfs_mos/mdl_tsvrak47sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvrak47sta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gfstsvrak47.05010930.$cycle"
export FORT31="$FIXgfs_mos/mdl_gfstsvrak47.10010430.$cycle"
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
export FORT28="$FIXgfs_mos/mdl_gfsposttsvrak47.$cycle"
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

#######################################################################
#  Note:  This fifth set of rainit through fcstpost is for the 20 km
#         convection forecasts.  They will be stored in the file gfsconv
#######################################################################
#
#######################################################################
#
#  PROGRAM RAINIT - INITIALIZES 20KM CONV RANDOM ACCESS FORECAST FILE
#
#######################################################################
#
export pgm=mdl_rainit
. prep_step
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_tsvr20sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr20sta.tbl"
export FORT49="mdl_gfsconv20.$cycle"
startmsg
$EXECcode/mdl_rainit < $PARMcode/mdl_u351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT for TSVR ended 

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
export FORT24="pkgfsraw.$DAT"
export FORT26="$FIXgfs_mos/mdl_tsvr20sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr20sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsconv20prd.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_constgrd20conv"
export FORT60="convprd20.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfspredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended 

#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS - FOR CONV
#
#######################################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT24="convprd20.$DAT"
export FORT26="$FIXgfs_mos/mdl_tsvr20sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr20sta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gfsconv20km.07011015.$cycle"
export FORT31="$FIXgfs_mos/mdl_gfsconv20km.10160315.$cycle"
export FORT32="$FIXgfs_mos/mdl_gfsconv20km.03160630.$cycle"
export FORT49="mdl_gfsconv20.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsevaltsvr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  EQNEVAL ended 

#######################################################################
#
#    PROGRAM FCSTPOST - POST-PROCESSES MOS FORECASTS - FOR TSVR
#
#######################################################################

echo MDLLOG: `date` - begin job FCSTPOST - POST PROCESS CONV FORECASTS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_tsvr20sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr20sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfspostconv20.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT49="mdl_gfsconv20.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfsposttsvr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended 

#######################################################################
# COPY FILES TO COM 
#######################################################################

if test $SENDCOM = 'YES' 
then
  cpfs mdl_gfsconv20.$cycle $COMOUT 
fi

#######################################################################
echo MDLLOG: `date` - Job exgfsmos_tstms_fcst has ended.
#######################################################################
