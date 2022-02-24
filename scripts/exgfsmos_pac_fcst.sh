#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_pac_fcst.sh.ecf
#  Purpose: To run all steps necessary to create short range GFS MOS 
#           fcsts for the Pacific sites.
#  Remarks: 
#  HISTORY: May 24, 2005      - new job for GFS gridded MOS
#                               This job currently runs at all
#                               4 cycles, but at 06 and 18Z it just 
#                               archives model data.
#           Mar 22, 2007      - added pieces for PoPO, PoP6, PoP12
#           Dec 03, 2012 EFE  - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Apr 07, 2014 EFE  - Set GDS from one file by parsing for a specific
#                               GDS line.
#           Oct 04, 2014 SDS  - Modified looping through tau and Changed 
#                               names of model GRIB2 files.
#           Jan 20, 2016 SDS  - Removed model processing portion of script,
#                               which now resides in pac_prep.
#           Jan 21, 2016 SDS  - Configured for MPMD
#
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_pac_fcst
set -x

cd $DATA/pac
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

######################################################################
#  COPY THE MDL GFS MODEL FILES FROM COM
#######################################################################
cpreq $COMIN/mdl_pacgfspkd.$cycle pac_pkgfsraw.$DAT

#######################################################################
#    RUN OBSPREP 
#    EVEN IF OBS ARE MISSING, WE NEED TO PRODUCE PKOBS FILE
#######################################################################

if test $cyc -eq '00'
then
 obhr1=03
 cp $COMINhry_mos/sfctbl.$obhr1 sfctbl.$obhr1
 if [ $? -ne 0 ]; then
    msg="WARNING: OBSERVATIONS NOT AVAILABLE FOR 03Z. USING SECONDARY EQUATIONS"
    postmsg "$jlogfile" "$msg"
 fi
elif test $cyc -eq '06'
then
 obhr1=09
 cp $COMINhry_mos/sfctbl.$obhr1 sfctbl.$obhr1
 if [ $? -ne 0 ]; then
    msg="WARNING: OBSERVATIONS NOT AVAILABLE FOR 09Z. USING SECONDARY EQUATIONS"
    postmsg "$jlogfile" "$msg"
 fi
elif test $cyc -eq '12'
then
 obhr1=15
 cp $COMINhry_mos/sfctbl.$obhr1 sfctbl.$obhr1
 if [ $? -ne 0 ]; then
    msg="WARNING: OBSERVATIONS NOT AVAILABLE FOR 15Z. USING SECONDARY EQUATIONS"
    postmsg "$jlogfile" "$msg"
 fi
elif test $cyc -eq '18'
then
 obhr1=21
 cp $COMINhry_mos/sfctbl.$obhr1 sfctbl.$obhr1
 if [ $? -ne 0 ]; then
    msg="WARNING: OBSERVATIONS NOT AVAILABLE FOR 21Z. USING SECONDARY EQUATIONS"
    postmsg "$jlogfile" "$msg"
 fi
fi

if [ ! -f sfctbl.$obhr1 ]
  then touch sfctbl.$obhr1
fi

export pgm=mdl_obsprep
. prep_step
export FORT10="ncepdate"
export FORT20="sfctbl.$obhr1"
export FORT26="$FIXgfs_mos/mdl_pacsta.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT70="pkobs.$DAT"
startmsg
$EXECcode/mdl_obsprep < $PARMgfs_mos/mdl_gfsobsprep.cn >> $pgmout 2>errfile
export err=$?

#!!!NOTE: AN ERROR HERE IS OK; OBS ARE NOT ESSENTIAL TO MOS FORECASTS!!!
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
export FORT50="mdl_pacgfsmos.$cycle"
startmsg
$EXECcode/mdl_racreate < $PARMcode/mdl_u350.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RACREATE ended 
#
#######################################################################
#
#  PROGRAM RAINIT - INITIALIZES RANDOM ACCESS MOS FORECAST
#                   FILE WITH STATION CALL LETTERS,
#                   ELEVATION, LATITUDE, AND LONGITUDE
#
#######################################################################
#
export pgm=mdl_rainit
. prep_step
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_pacsta.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT49="mdl_pacgfsmos.$cycle"
startmsg
$EXECcode/mdl_rainit < $PARMcode/mdl_u351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT ended 

#
#######################################################################
#
#    FIRST EXECUTION OF PROGRAM MOSPRED 
#    MOSPRED - USED TO INTERPOLATE TO STATIONS FROM MDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT24="pac_pkgfsraw.$DAT"
export FORT26="$FIXgfs_mos/mdl_pacsta.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT28="$FIXgfs_mos/mdl_pacgfsprd"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXgfs_mos/mdl_pacconststa"
export FORT60="pacgfsmodel.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfspredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended 

#
#######################################################################
#
#    SECOND EXECUTION OF PROGRAM MOSPRED
#    MOSPRED - USED TO CREATE OBSERVED PREDICTORS FROM THE MDL  
#              OBSERVATIONAL TABLES.
#
#######################################################################
#
echo MDLLOG: `date` - begin job MOSPRED - CREATE OBSERVATIONAL PREDICTORS
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT80="pkobs.$DAT"
export FORT26="$FIXgfs_mos/mdl_pacsta.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT28="$FIXgfs_mos/mdl_pacgfsprd.obs"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT61="mdl_pacgfsobs.$cycle"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfspredobs.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  Second use of MOSPRED ended 

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
export FORT23="mdl_pacgfsobs.$cycle"
export FORT24="pacgfsmodel.$DAT"
export FORT26="$FIXgfs_mos/mdl_pacsta.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_pacgfswind.06010930.$cycle"
export FORT31="$FIXgfs_mos/mdl_pacgfswind.10010531.$cycle"
export FORT32="$FIXgfs_mos/mdl_pacgfspop.05011031.$cycle"
export FORT33="$FIXgfs_mos/mdl_pacgfspop.11010430.$cycle"
export FORT34="$FIXgfs_mos/mdl_pacgfspopo.05011031.$cycle"
export FORT35="$FIXgfs_mos/mdl_pacgfspopo.11010430.$cycle"
export FORT36="$FIXgfs_mos/mdl_pacgfsttd.05011031.$cycle"
export FORT37="$FIXgfs_mos/mdl_pacgfsttd.11010430.$cycle"
export FORT38="$FIXgfs_mos/mdl_pacgfsceiling.05011031.$cycle"
export FORT39="$FIXgfs_mos/mdl_pacgfsceiling.11010430.$cycle"
export FORT40="$FIXgfs_mos/mdl_pacgfsopqcld.05011031.$cycle"
export FORT41="$FIXgfs_mos/mdl_pacgfsopqcld.11010430.$cycle"
export FORT49="mdl_pacgfsmos.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_pacgfseval.cn.$cycle >> $pgmout 2>errfile
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
export FORT26="$FIXgfs_mos/mdl_pacsta.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT28="$FIXgfs_mos/mdl_pacgfspost.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT45="$FIXgfs_mos/mdl_pacconststa"
export FORT47="$FIXgfs_mos/mdl_pacthreshold"
export FORT49="mdl_pacgfsmos.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfspost.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended 

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_pacgfsmos.$cycle $COMOUT
  cpfs mdl_pacgfsobs.$cycle $COMOUT
  cpfs pacgfsmodel.$DAT $COMOUT/mdl_pacgfsprdpkd.$cycle
fi

echo MDLLOG: `date` - Job gfsmos_pac_fcst has ended.
#######################################################################
