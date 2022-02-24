#!/bin/sh
#######################################################################
#
#  Job Name: exgfsmos_higoe_fcst.sh.ecf
#
#   Purpose: To run all steps necessary to create the GFS-based short- 
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
#   History: Aug 17, 2010 EFE - New job for HI GMOS prep and GOE for
#                               the short-range.
#            Dec 03, 2012 EFE - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '.
#                               Added creation of GRIB2 index file to
#                               provide as input to copygb2 for faster
#                               runtime.
#            Apr 07, 2014 EFE - Modified GRIB2 regridding method. wgrib2
#                               is now used to parse fields, and copygb2
#                               to perform regridded from global lat/lon
#                               to NPS 47km grid over Hawaii NDGD domain.
#            Oct 04, 2014 SDS - Modified looping through tau and changed
#                               names of model GRIB2 files.
#            Jan 20, 2016 SDS - Removed model processing part of script,
#                               since the prep47 script is archived on 
#                               a large enough grid for Hawaii.
#            Jan 21, 2016 SDS - Configured for MPMD
#
#######################################################################                                                                                                               
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_higoe_fcst
set -x

cd $DATA/higoe
cpreq $DATA/ncepdate .

DAT="${PDY}${cyc}"
echo $PDY $cyc: Date and Cycle - echo PDY and cyc

#######################################################################
#  COPY THE MDL 0-96 HR GFS MODEL FILE FROM COM
#######################################################################
cpreq $COMIN/mdl_gfspkd47.$cycle .

#######################################################################
# PROGRAM RACREATE - MOS-2000 PROGRAM WHICH
#                    CREATES RANDOM ACCESS FILES; IN THIS CASE, THE
#                    CODE IS USED TO CREATE THE OPERATIONAL MOS
#                    FORECAST FILE. THIS ONE HAS A SPECIAL CN FILE FOR
#                    GMOS
#######################################################################
echo MDLLOG: `date` - begin job RACREATE - CREATE MOS FORECAST FILE

export pgm=mdl_racreate
. prep_step
export FORT50="mdl_goehimos.$cycle"
startmsg
$EXECcode/mdl_racreate < $PARMgfs_mos/mdl_gmosu350.cn >> $pgmout 2> errfile
export err=$?; err_chk

echo MDLLOG: `date` - RACREATE ended
#######################################################################
#  PROGRAM RAINIT - INITIALIZES RANDOM ACCESS MOS FORECAST
#                   FILE WITH STATION CALL LETTERS,
#                   ELEVATION, LATITUDE, AND LONGITUDE
#######################################################################
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE

export pgm=mdl_rainit
. prep_step
export FORT10="ncepdate"
export FORT27="$FIXgfs_mos/mdl_hindfdtrimsta.tbl"
export FORT49="mdl_goehimos.$cycle"
startmsg
$EXECcode/mdl_rainit < $PARMgfs_mos/mdl_gmosu351.cn >> $pgmout 2> errfile
export err=$?; err_chk

echo MDLLOG: `date` - RAINIT ended
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
export FORT24="mdl_gfspkd47.$cycle"
export FORT27="$FIXgfs_mos/mdl_hindfdtrimsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsgoehiprd.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_consthindfdtrimsta"
export FORT60="goehimosmodel.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfsgmospredmdl.cn >> $pgmout 2> errfile
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
export FORT24="goehimosmodel.$DAT"
export FORT27="$FIXgfs_mos/mdl_hindfdtrimsta.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT35="$FIXgfs_mos/mdl_gfsgoehipopqpf.04010930.$cycle"
export FORT36="$FIXgfs_mos/mdl_gfsgoehipopqpf.10010331.$cycle"
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
export FORT28="$FIXgfs_mos/mdl_gfsgoepost_hi.$cycle"
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
  cpfs goehimosmodel.$DAT $COMOUT/mdl_goehimosmodel.$cycle
fi

echo MDLLOG: `date` - Job exgfsmos_higoe_fcst has ended.
#######################################################################
