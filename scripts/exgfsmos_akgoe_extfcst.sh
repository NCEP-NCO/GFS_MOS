#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_akgoe_extfcst.sh.ecf
#  Purpose: To run all steps necessary to create the GFS-based extended- 
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
#                               Also changed the check in the beginning
#                               to look for the goe random access file
#                               from the short-range job.
#           Dec 03, 2012 EFE  - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Feb 10, 2016 SDS  - Configured for MPMD
#           Feb 2018     GAW  - Split off exgfsmos_akgoe_extprep.sh.ecf
#                               to run model prep pieces concurrent with 
#                               other prep steps
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
echo MDLLOG: `date` - Begin job exgfsmos_akgoe_extfcst
set -x

cd $DATA/akgoe
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
#
#    THIS JOB USES THE RANDOM ACCESS FILE FIRST CREATED IN THE
#    EXECUTION OF GFSMOS_AKGOE_FCST.  CHECK IF THE FILE MDL_GOEAKMOS.TXXZ
#    EXISTS IN COM/GFS.  IF IT DOES, COPY THE FILE TO THE WORK SPACE.
#    IF IT DOES NOT EXIST, THE SCRIPT WILL ABORT.  GFSMOS_AKGOE_EXTFCST
#    WILL NOT WORK UNLESS GFSMOS_AKGOE_FCST HAS ALREADY RUN SUCCESSFULLY.
#######################################################################
#
if [ ! -f $COMIN/mdl_goeakmos.$cycle ]
     then echo 'need successful run of gfsmos_akgoe_fcst to run properly' >> $pgmout        
             export err=1;err_chk
fi

cpreq $COMIN/mdl_goeakmos.$cycle .

#######################################################################
# COPY MODEL FILES TO TEMP SPACE 
#######################################################################
cpreq $COMIN/mdl_gfspkdgmosak.$cycle pkgfsraw.$DAT
cpreq $COMIN/pkgfsxrawgmosak.$DAT .

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
export FORT24="pkgfsxrawgmosak.$DAT"
export FORT26="$FIXgfs_mos/mdl_granlsta_ak.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_ak.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxgrpost_gfscalc.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="pkgfsxrawgmosak_calc.$DAT"
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_gfs.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended

cat pkgfsxrawgmosak.$DAT pkgfsxrawgmosak_calc.$DAT > mdl_gfsxpkdgmosak.$cycle
cpfs mdl_gfsxpkdgmosak.$cycle  $COMOUT/.

cpreq $COMOUT/mdl_gfspkdgmosak.$cycle .

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
export FORT23="mdl_gfspkdgmosak.$cycle"
export FORT24="mdl_gfsxpkdgmosak.$cycle"
export FORT27="$FIXgfs_mos/mdl_akndfdsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxgoeakprd.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_constakndfdsta"
export FORT60="goeakmosxmodel.$DAT"
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
export IOBUF_PARAMS=''
#export IOBUF_PARAMS='*:size=4M:'
echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT24="goeakmosxmodel.$DAT"
export FORT27="$FIXgfs_mos/mdl_akndfdsta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT35="$FIXgfs_mos/mdl_gfsxgoeakpopqpf.04010930.$cycle"
export FORT36="$FIXgfs_mos/mdl_gfsxgoeakpopqpf.10010331.$cycle"
export FORT37="$FIXgfs_mos/mdl_gfsxgoeakcld.04010930.$cycle"
export FORT38="$FIXgfs_mos/mdl_gfsxgoeakcld.10010331.$cycle"
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
export FORT28="$FIXgfs_mos/mdl_gfsxgoeakpost.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT45="$FIXgfs_mos/mdl_constakndfdsta"
export FORT47="$FIXgfs_mos/mdl_goeakthreshold"
export FORT49="mdl_goeakmos.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gmospost.cn >> $pgmout 2>errfile
export err=$?; err_chk

echo MDLLOG: `date` -  FCSTPOST ended

#######################################################################
#
#    PROGRAM GRIDPOST - THIS IS ACTUALLY A "PRE-PROCESSOR" FOR ALASKA
#                       GRIDDED MOS EXTRA-EXTENDED RANGE. NEED TO
#                       CREATE UPPER-AIR DATA FOR UPPER-AIR DATA FOR
#                       PROJECTIONS 198-, 210-, 222-, 234-, 246-, AND
#                       258-H. THESE PROJECTIONS ARE NOT AVAILABLE
#                       DIRECTLY FROM THE MODEL, THEREFORE WE NEED TO
#                       TEMPORALLY INTERPOLATE TO THESE PROJECTIONS.
#
#######################################################################
echo MDLLOG: `date` - begin job GRIDPOST - POST PROCESS MOS FORECASTS
export pgm=mdl_gridpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_granlsta_ak.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_ak.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxxgrpost_akpre.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT61="pkgfsxrawgmosak.$DAT"
export FORT60="pkgfsxxrawgmosak.$cycle"
startmsg
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_akpre.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs goeakmosxmodel.$DAT $COMOUT/mdl_goeakmosxmodel.$cycle
  cpfs mdl_goeakmos.$cycle $COMOUT
  cpfs pkgfsxxrawgmosak.$cycle $COMOUT/mdl_pkgfsxxrawgmosak.$cycle
fi

echo MDLLOG: `date` - Job exgfsmos_akgoe_extfcst has ended.
#######################################################################
