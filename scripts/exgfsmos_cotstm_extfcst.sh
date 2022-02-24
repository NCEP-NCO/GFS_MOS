#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_cotstm_extfcst.sh.ecf
#
#  Purpose: To run all steps necessary to create extended range GFS-based
#           gridded MOS thunderstorm fcsts on the CONUS 2.5 km NDFD Grid.
#  Remarks: These are the GMOS thunderstorms post-processed to have a smooth
#           boundary offshore.
#
#  HISTORY: 2012-06-06  Huntemann  MDL  New job for CONUS 2.5 km Gridded MOS
#                                       thunderstorms.  Adapted from 2.5 km
#                                       Gridded MOS prdgen scripts.  
#           2012-11-15  Huntemann  MDL  Adapted to run on Intel WCOSS
#           2013-11-15  Huntemann  MDL  Updated for operations.
#           2016-02-11  Scallion   MDL  Configured for MPMD
#######################################################################
#
PS4='cotstm_extfcst $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
set -x

echo MDLLOG: `date` - Begin job $0

cd $DATA/cotstm
cpreq $DATA/ncepdate .

#
#######################################################################
#
# PROGRAM GRANALYSIS_CO - PERFORMS THE ANALYSIS OF THE MOS FORECASTS
#                         ONTO A GRID.
#
#######################################################################
#
cpreq $COMIN/mdl_gfstsvr40.$cycle mdl_gfstsvr40.$cycle
cpreq $COMOUT/mdl_gfsgmoscotstm.$cycle .
cpreq $COMOUT/mdl_gfsgmoscotstm_grsq.$cycle .

echo MDLLOG: `date` - begin job GRANALYSIS_CO
export pgm=mdl_granalysis_co
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXcode/mdl_tsvr40sta.lst_wx"
export FORT27="$FIXgfs_mos/mdl_tsvr40sta.tbl_wx"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT38="$FIXgfs_mos/mdl_gfsxtstmgranlids_co.$cycle"
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_co"
export FORT51="$FIXgfs_mos/mdl_u405atstm03cocn"
export FORT52="$FIXgfs_mos/mdl_u405atstm06cocn"
export FORT53="$FIXgfs_mos/mdl_u405atstm12cocn"
export FORT54="$FIXgfs_mos/mdl_u405atstm06xcocn"
export FORT49="mdl_gfstsvr40.$cycle"
export FORT31="mdl_gfsgmoscotstm_xgrsq.$cycle"
export FORT42="mdl_gfsgmoscotstm.$cycle"
$EXECcode/mdl_granalysis_co < $PARMgfs_mos/mdl_granalysis_cotstm.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRANALYSIS_CO ended

#TLH 2013-11-15 is the following necessary?
cat mdl_gfsgmoscotstm_grsq.$cycle mdl_gfsgmoscotstm_xgrsq.$cycle > mdl_gfsgmoscotstm_fullgrsq.$cycle
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
export FORT28="$FIXgfs_mos/mdl_gfsxtstmgrpost_co.$cycle"
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
  cpfs mdl_gfsgmoscotstm_xgrsq.$cycle $COMOUT
  cpfs mdl_gfsgmoscotstm_fullgrsq.$cycle $COMOUT
fi

echo MDLLOG: `date` - End job $0

exit
