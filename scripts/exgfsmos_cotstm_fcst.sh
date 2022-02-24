#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_cotstm_fcst.sh
#
#  Purpose: To run all steps necessary to create short range GFS-based
#           gridded MOS thunderstorm fcsts on the CONUS 2.5 km NDFD Grid.
#
#  Remarks: This script re-creates the GMOS thunderstorms with a
#           "smooth" boundary.
#
#  HISTORY: 2012-06-06  Huntemann  New job for CONUS 2.5 km Gridded MOS
#                                  thunderstorms.  Adapted from 2.5 km
#                                  Gridded MOS prdgen scripts.  
#           2012-11-15  Huntemann  Adapted for Intel/WCOSS
#           2013-04-03  Huntemann  Added check for model data. This
#                                  script will sleep up to 2 hours if
#                                  model data is not present.
#           2013-11-07  Huntemann  Adapted for operations.
#           2013-12-04  Scallion   Removed sleep. Copy input file into
#                                  working (DATA) directory.
#           2016-01-21  Scallion   Configured for MPMD
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
set -x

echo MDLLOG: `date` - Begin job $0

cd $DATA/cotstm
cpreq $DATA/ncepdate .

#######################################################################
#  COPY THE GFS MODEL DATA FROM COM
#######################################################################
cpreq $COMIN/mdl_gfstsvr40.$cycle .

#
#######################################################################
#
# PROGRAM GRANALYSIS_CO - PERFORMS THE ANALYSIS OF THE MOS FORECASTS
#                         ONTO A GRID.
#
# FIRST: COPY THE RANDOM ACCESS TEMPLATE FILE FROM FIX. WE DON'T HAVE
#        GFSXMERGESTA YET SO TOUCH THE FILE TO CREATE IT.
#
#  NOTE: THE UPPER AIR DATA FOR LAPSE RATE COMPUTATION COMES FROM
#        THE 95KM MODEL ARCHIVE FILE
#######################################################################
#
cpreq $FIXcode/mdl_rafile_template mdl_gfsgmoscotstm.$cycle

echo MDLLOG: `date` - begin job GRANALYSIS_CO
export pgm=mdl_granalysis_cotstm
. prep_step
startmsg
export FORT10="ncepdate"
#export FORT26="$FIXcode/mdl_tsvr40sta.lst"
export FORT26="$FIXcode/mdl_tsvr40sta.lst_wx"
export FORT27="$FIXgfs_mos/mdl_tsvr40sta.tbl_wx"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT38="$FIXgfs_mos/mdl_gfststmgranlids_co.$cycle"
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_co"
export FORT51="$FIXgfs_mos/mdl_u405atstm03cocn"
export FORT52="$FIXgfs_mos/mdl_u405atstm06cocn"
export FORT53="$FIXgfs_mos/mdl_u405atstm12cocn"
export FORT54="$FIXgfs_mos/mdl_u405atstm06xcocn"
export FORT49="mdl_gfstsvr40.$cycle"
export FORT31="mdl_gfsgmoscotstm_grsq.$cycle"
export FORT42="mdl_gfsgmoscotstm.$cycle"
$EXECcode/mdl_granalysis_co < $PARMgfs_mos/mdl_granalysis_cotstm.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRANALYSIS_CO ended

#
#######################################################################
#
# PROGRAM GRIDPOST - PERFORMS POST-PROCESSING OF THE GRIDDED MOS
#                    FORECASTS.
#######################################################################
#
echo MDLLOG: `date` - begin job GRIDPOST - POST PROCESS MOS FORECASTS
export pgm=mdl_gridpost
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_granlsta_co.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_co.tbl"
export FORT28="$FIXgfs_mos/mdl_gfststmgrpost_co.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT42="mdl_gfsgmoscotstm.$cycle"
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_co.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  # TDLPACK FILES
  cpfs mdl_gfsgmoscotstm.$cycle $COMOUT
  cpfs mdl_gfsgmoscotstm_grsq.$cycle $COMOUT
fi

#######################################################################
echo MDLLOG: `date` - Job $0 has ended.
#######################################################################
