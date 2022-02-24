#!/bin/sh
#######################################################################
#
#  Job Name: exgfsmos_higoe_extfcst.sh.ecf
#
#   Purpose: To run all steps necessary to create the GFS-based extended- 
#            range MOS and model data for Hawaii gridded MOS. This
#            runs all the steps necessary to create the forecasts.
#            Subsequent scripts will produce the guidance products.
#            This script runs at 00 and 12Z.   
#
#   Remarks: For the forseeable future, this script will produce     
#            TDLPACK files of model data interpolated from GFS 0.5 deg.
#            PGRIB2 files to a NPS grid over Hawaii GMOS domain. This
#            grid is a subgrid of the "new" MDL GFS model archive that
#            was apporved as the new archive grid in Aug. 2010. The new
#            grid is expanded to cover all North American NDFD/NDGD
#            domains. 
#
#   History: Mar 21, 2008 EFE - New job for GFS Gridded MOS for HI.
#                               At the current time this job is just
#                               a run of mospred to get model data
#                               as input to U155 for the temp fields.
#                               In time we'll add the other forecast
#                               steps when we have the goes ready.
#            Sep 25, 2008 EFE - Added steps to evaluated POP and sky
#                               goes.  Also added ids to u201 to get
#                               DMO winds for wind first guess and lapse.
#            Aug 17, 2010 EFE - Added section to perform interp of GFS
#                               model data from Lat/Lon grids to NPS
#                               grids at 47KM (99-h to 192-h) and 95KM 
#                               (204-h to 384-h)over Hawaii and then
#                               convert to TDLPACK file. Cleaned up script
#                               for operations.
#            Dec 03, 2012 EFE - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#                               Added creation of GRIB2 index file to
#                               provide as input to copygb2 for faster
#                               runtime.
#            Apr 07, 2014 EFE - Modified GRIB2 regridding method. wgrib2
#                               is now used to parse fields, and copygb2
#                               to perform regridded from global lat/lon
#                               to NPS 47km/95km grid over Hawaii NDGD domain.
#            Aug 22, 2014 SDS - Modified for loop to include additional
#                               3-hourly projections and to change the 1
#                               degree cut-off to tau 252.
#            Feb 10, 2016 SDS - Configured for MPMD
#            Feb 12, 2016 SDS - Removed model data processing
#######################################################################                                                                                                               
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_higoe_extfcst
set -x

cd $DATA/higoe
cpreq $DATA/ncepdate .

DAT="${PDY}${cyc}"
echo $PDY $cyc: Date and Cycle - echo PDY and cyc

#######################################################################
#######################################################################
# CREATE THE GOE FILES.
#######################################################################
#######################################################################
# THIS JOB USES THE RANDOM ACCESS FILE FIRST CREATED IN THE
# EXECUTION OF GFSMOS_HIGOE_FCST.  CHECK IF THE FILE MDL_GOEHIMOS.TXXZ
# EXISTS IN COM/GFS.  IF IT DOES, COPY THE FILE TO THE WORK SPACE.
# IF IT DOES NOT EXIST, THE SCRIPT WILL ABORT.  GFSMOS_HIGOE_EXTFCST
# WILL NOT WORK UNLESS GFSMOS_HIGOE_FCST HAS ALREADY RUN SUCCESSFULLY.
#######################################################################
if [ ! -f $COMIN/mdl_goehimos.$cycle ]
then
   echo 'need successful run of gfsmos_higoe_fcst to run properly' >> $pgmout
   export err=1;err_chk
fi
cpreq $COMIN/mdl_goehimos.$cycle .
cpreq $COMIN/mdl_gfspkd47.$cycle .
cpreq $COMIN/mdl_gfsxpkd47.$cycle .
#######################################################################
#  PROGRAM MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#                    ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#                    THIS RUN GETS THE MODEL FIELDS THAT WE NEED FOR 
#                    FIRST GUESS AND UPPER AIR LAPSE RATE CALCULATIONS IN
#                    ADDITION TO PREDICTORS FOR THE GOES
#
#  NOTE: AT THIS TIME UNIT 44 IS NOT BEING USED IN THIS RUN
#        OF MOSPRED.  THIS IS THE CONUS FILE AND IS LEFT HERE SO
#        THE SAME CN FILE CAN BE USED AS IN THE CONUS.
#######################################################################
echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA

export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT23="mdl_gfspkd47.$cycle"
export FORT24="mdl_gfsxpkd47.$cycle"
export FORT27="$FIXgfs_mos/mdl_hindfdtrimsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxgoehiprd.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_consthindfdtrimsta"
export FORT60="goehimosxmodel.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfsxgmospredmdl.cn >> $pgmout 2> errfile
export err=$?; err_chk

echo MDLLOG: `date` -  MOSPRED ended
#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS
#
#######################################################################
echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS

export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT24="goehimosxmodel.$DAT"
export FORT27="$FIXgfs_mos/mdl_hindfdtrimsta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT35="$FIXgfs_mos/mdl_gfsxgoehipopqpf.04010930.$cycle"
export FORT36="$FIXgfs_mos/mdl_gfsxgoehipopqpf.10010331.$cycle"
export FORT49="mdl_goehimos.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsgmoshieval.cn.$cycle >> $pgmout 2> errfile
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
export FORT27="$FIXgfs_mos/mdl_hindfdtrimsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxgoepost_hi.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT45="$FIXgfs_mos/mdl_consthindfdtrimsta"
export FORT47="$FIXgfs_mos/mdl_goethreshold"
export FORT49="mdl_goehimos.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gmospost.cn >> $pgmout 2> errfile
export err=$?; err_chk

echo MDLLOG: `date` -  FCSTPOST ended
#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_goehimos.$cycle $COMOUT
  cpfs goehimosxmodel.$DAT $COMOUT/mdl_goehimosxmodel.$cycle
fi

echo MDLLOG: `date` - Job exgfsmos_higoe_extfcst has ended.
#######################################################################
