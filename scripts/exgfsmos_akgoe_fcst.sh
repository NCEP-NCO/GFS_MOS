#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_akgoe_fcst.sh.ecf
#  Purpose: To run all steps necessary to create the GFS-based short- 
#           range MOS and model data for Alaska gridded MOS.  
#           This script runs all the steps to create the
#           forecasts.  Subsequent scripts will produce the products.
#           This script runs at 00 and 12Z.   
#  Remarks: 
#  HISTORY: Mar 21, 2008      - New job for GFS Gridded MOS for AK.
#                               At the current time this job is just
#                               a run of mospred to get model data
#                               as input to U155 for the temp fields.
#                               In time we'll add the other forecast
#                               steps when we have the goes ready.
#           Sep 25, 2008      - Added steps to evaluated POP and sky
#                               goes.  Also added ids to u201 to get
#                               dmo winds for wind first guess and lapse.
#           Dec 03, 2012 EFE  - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Jan 21, 2016 SDS  - Configured for MPMD
#           Feb 2018     GAW  - Split off exgfsmos_akgoe_prep.sh.ecf
#                               to run model prep pieces concurrent with 
#                               other prep steps
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
echo MDLLOG: `date` - Begin job exgfsmos_akgoe_fcst
set -x

cd $DATA/akgoe
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"
cpreq $COMIN/pkgfsrawgmosak.$DAT .

#######################################################################
#
# PROGRAM GRIDPOST - PERFORMS POST-PROCESSING OF THE TDLPACK GFS MODEL
#                    DATA.
#######################################################################
echo MDLLOG: `date` - begin job GRIDPOST - POST PROCESS MOS FORECASTS

export pgm=mdl_gridpost
. prep_step
startmsg
export FORT10="ncepdate"
export FORT24="pkgfsrawgmosak.$DAT"
export FORT26="$FIXgfs_mos/mdl_granlsta_ak.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_ak.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsgrpost_gfscalc.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="pkgfsrawgmosak_calc.$DAT"
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_gfs.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended

cat pkgfsrawgmosak.$DAT pkgfsrawgmosak_calc.$DAT > mdl_gfspkdgmosak.$cycle
cpfs mdl_gfspkdgmosak.$cycle $COMOUT/.

#
#######################################################################
#
# PROGRAM RACREATE - MOS-2000 PROGRAM WHICH
#                   CREATES RANDOM ACCESS FILES; IN THIS CASE, THE
#                   CODE IS USED TO CREATE THE OPERATIONAL MOS
#                   FORECAST FILE.
# THIS ONE HAS A SPECIAL CN FILE FOR GMOS
#######################################################################
#
echo MDLLOG: `date` - begin job RACREATE - CREATE MOS FORECAST FILE
export pgm=mdl_racreate
. prep_step
export FORT50="mdl_goeakmos.$cycle"
startmsg
$EXECcode/mdl_racreate < $PARMgfs_mos/mdl_gmosu350.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - RACREATE ended

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
export FORT27="$FIXgfs_mos/mdl_akndfdsta.tbl"
export FORT49="mdl_goeakmos.$cycle"
startmsg
$EXECcode/mdl_rainit < $PARMgfs_mos/mdl_gmosu351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - RAINIT ended

#
#######################################################################
#
#  PROGRAM MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#           THIS RUN GETS THE MODEL FIELDS THAT WE NEED FOR 
#           FIRST GUESS AND UPPER AIR LAPSE RATE CALCULATIONS IN
#           ADDITION TO PREDICTORS FOR THE GOES
#
#  NOTE: AT THIS TIME UNIT 44 IS NOT BEING USED IN THIS RUN
#        OF MOSPRED.  THIS IS THE CONUS FILE AND IS LEFT HERE SO
#        THE SAME CN FILE CAN BE USED AS IN THE CONUS.
#######################################################################
echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT24="mdl_gfspkdgmosak.$cycle"
export FORT27="$FIXgfs_mos/mdl_akndfdsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsgoeakprd.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_constakndfdsta"
export FORT60="goeakmosmodel.$DAT"
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
export FORT24="goeakmosmodel.$DAT"
export FORT27="$FIXgfs_mos/mdl_akndfdsta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT35="$FIXgfs_mos/mdl_gfsgoeakpopqpf.04010930.$cycle"
export FORT36="$FIXgfs_mos/mdl_gfsgoeakpopqpf.10010331.$cycle"
export FORT37="$FIXgfs_mos/mdl_gfsgoeakcld.04010930.$cycle"
export FORT38="$FIXgfs_mos/mdl_gfsgoeakcld.10010331.$cycle"
export FORT49="mdl_goeakmos.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsgmosakeval.cn.$cycle >> $pgmout 2>errfile
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
export FORT27="$FIXgfs_mos/mdl_akndfdsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsgoeakpost.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT45="$FIXgfs_mos/mdl_constakndfdsta"
export FORT47="$FIXgfs_mos/mdl_goeakthreshold"
export FORT49="mdl_goeakmos.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gmospost.cn >> $pgmout 2>errfile
export err=$?; err_chk

echo MDLLOG: `date` -  FCSTPOST ended 


#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs goeakmosmodel.$DAT $COMOUT/mdl_goeakmosmodel.$cycle
  cpfs mdl_goeakmos.$cycle $COMOUT
fi


echo MDLLOG: `date` - Job exgfsmos_akgoe_fcst has ended.
#######################################################################
