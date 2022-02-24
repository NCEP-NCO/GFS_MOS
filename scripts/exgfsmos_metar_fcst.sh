#!/bin/sh
#######################################################################
#  Job Name: exgfsmos.sh.ecf (formerly exavnmos.sh.sms)
#  Purpose: To run all steps necessary to create short range GFS MOS fcsts
#  Remarks: 
#  HISTORY: May 16, 2000      - new job for AVN MOS2000
#           July 5, 2000  RLA - implemented ptype and warm season 
#                               clouds.
#           Aug 30, 2000  RLA - implemented cool season winds & temps
#           SEP 25, 2000  MAS - implemented cool season pops vis & tsvr
#           Jan 23, 2001  RLA - implemented warm season vis/obv and fix
#                               to cool season vis/obv
#           Feb 18, 2001  RLA - implemented spring season tsvr eqns
#           MAR 19, 2001  MAS - implemented bufr code
#           APR 23, 2001  JCM - implemented ra2tdlp
#           JUN 27, 2001  MCE - implemented warm popqpf
#           JUN 27, 2001  RLA - implemented warm & cool popc, fixed
#                               warm vis/obv.
#           AUG 24, 2001 RA/MCE implemented Air Force text message
#           AUG 31, 2001  RLA - implemented cool popqpf and fix to
#                               cld/cig rfs.
#           SEP 24, 2001 RA/MCE implemented grib code and fix to dictionary.
#           NOV 05, 2001 MCE  - pulled temporary 6/18Z script together with
#                               00/12Z script to have one AVN MOS script for
#                               all four cycles.
#           JAN 9,  2002 RLC  - changed tdl_mos2grd1081.tbl to tdl_mos2grd.tbl
#                               when stations were upped to 1432
#           APR 6,  2002 RLC  - added step to create FECN20(Canadian txt)
#           JUN 12, 2002 RLC  - added dbnet alerts to get files to TGFTP       
#           AUG 01, 2002 JCM  - updated for new grb2tdlp and tdl_gridlst
#           AUG 12, 2002 RC/CM- added 6/18 visobvis, POPO, POPO3 for all
#                               four cycles, changed all code and script
#                               pieces from FECN20 to FOCN20.
#           AUG 20, 2002 RLC  - added piece to archive Eta tsvr at 12Z
#           MAY  6, 2003 RC/CM -added marine MOS sites to system, added
#                               marine MOS text message
#           AUG 20, 2003 RLC  - GFS TRANSTITION - merged AVN and MRF
#                               processing into one GFS paradigm.  At    
#                               this time, the avnmos script will do
#                               the MAV (out to 84/90-h)
#                               forecasts and products.  Both avnmos
#                               and mrfmos jobs will write to gfsmos
#                               random access file.  The archiving of
#                               all the GFS MOS forecasts will be in 
#                               the mrf job.
#           MAR 10, 2004 JCM  - Eta and GFS gridded constants files
#                               have been merged into one file; this
#                               required renaming the file on unit 44.
#           APR 30, 2004 RLC  - Added a line for the old visibility
#                               equations that we have to keep running
#                               for the BUFR and GRIB products for now.
#           JUL 31, 2004 RLC  - Added another line for the old visibility.
#           DEC 13, 2004 JCM  - GRIDDED MOS:  Stripped out TSTM stuff, this 
#                               script now only runs through the 
#                               post-processor.
#           APR 26, 2006 JCM  - Added processing for wind gusts in EQNEVAL
#           JUL 07, 2006 RLC  - Took out old visobv equations
#           Feb 28, 2007 RLC  - Added opaque sky cover equations.
#           Dec  2, 2009 JCM  - New P-Type, Ceiling
#           Dec 03, 2012 EFE  - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Jan 21, 2016 SDS  - Configured for MPMD
#           Apr 18, 2017 SDS  - Added new CIG/OPQCLD equations to EQNEVAL,
#                               eliminating the ceiling UNIT numbers, 
#                               since they are now developed together.
#
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_metar_fcst

set -x

cd $DATA/metar
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
#  COPY THE MDL 0-96 HR GFS MODEL FILE FROM COM
#######################################################################
cpreq $COMIN/mdl_gfspkd47.$cycle pkgfsraw.$DAT

#######################################################################
#    RUN OBSPREP
#    EVEN IF OBS ARE MISSING, WE NEED TO PRODUCE PKOBS FILE
#######################################################################

if test $cyc == '00'
#if test $cyc -eq '00'
then
 obhr1=03
 cp $COMINhry_mos/sfctbl.$obhr1 sfctbl.$obhr1
 if [ $? -ne 0 ]; then
    msg="WARNING: OBSERVATIONS NOT AVAILABLE FOR 03Z. USING SECONDARY EQUATIONS"
    postmsg "$jlogfile" "$msg"
 fi
elif test $cyc == '06'
#elif test $cyc -eq '06'
then
 obhr1=09
 cp $COMINhry_mos/sfctbl.$obhr1 sfctbl.$obhr1
 if [ $? -ne 0 ]; then
    msg="WARNING: OBSERVATIONS NOT AVAILABLE FOR 06Z. USING SECONDARY EQUATIONS"
    postmsg "$jlogfile" "$msg"
 fi
elif test $cyc == '12'
#elif test $cyc -eq '12'
then
 obhr1=15
 cp $COMINhry_mos/sfctbl.$obhr1 sfctbl.$obhr1
 if [ $? -ne 0 ]; then
    msg="WARNING: OBSERVATIONS NOT AVAILABLE FOR 15Z. USING SECONDARY EQUATIONS"
    postmsg "$jlogfile" "$msg"
 fi
elif test $cyc == '18'
#elif test $cyc -eq '18'
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
export FORT26="$FIXcode/mdl_station.lst"
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

echo MDLLOG: `date` - begin job RACREATE - CREATE MOS FORECAST FILE

export pgm=mdl_racreate
. prep_step
export FORT50="mdl_gfsmos.$cycle"
startmsg
$EXECcode/mdl_racreate < $PARMcode/mdl_u350.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RACREATE ended 

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
export FORT26="$FIXcode/mdl_station.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT49="mdl_gfsmos.$cycle"
startmsg
$EXECcode/mdl_rainit < $PARMcode/mdl_u351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT ended 


#######################################################################
#
#    FIRST EXECUTION OF PROGRAM MOSPRED 
#    MOSPRED - USED TO INTERPOLATE TO STATIONS FROM TDL GRID-POINT
#              ARCHIVE FILES AND TO PROCESS/COMBINE VECTOR DATA.
#
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - INTERPOLATE MODEL DATA
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT24="pkgfsraw.$DAT"
export FORT26="$FIXcode/mdl_station.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsprd.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXcode/mdl_conststa"
export FORT60="gfsmodel.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfspredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended 


#######################################################################
#
#    SECOND EXECUTION OF PROGRAM MOSPRED
#    MOSPRED - USED TO CREATE OBSERVED PREDICTORS FROM THE MDL  
#              OBSERVATIONAL TABLES.
#
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - CREATE OBSERVATIONAL PREDICTORS
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT80="pkobs.$DAT"
export FORT26="$FIXcode/mdl_station.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsprd.obs"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT61="mdl_gfsobs.$cycle"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfspredobs.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  Second use of MOSPRED ended 


#######################################################################
#
#    PROGRAM EQNEVAL - CALCULATES MOS FORECASTS
#
#######################################################################

echo MDLLOG: `date` - begin job EQNEVAL - MAKE MOS FORECASTS
export pgm=mdl_eqneval
. prep_step
export FORT10="ncepdate"
export FORT23="mdl_gfsobs.$cycle"
export FORT24="gfsmodel.$DAT"
export FORT26="$FIXcode/mdl_station.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gfswind.04010930.$cycle"
export FORT31="$FIXgfs_mos/mdl_gfswind.10010331.$cycle"
export FORT32="$FIXgfs_mos/mdl_gfsmxmntd84.04010930.$cycle"
export FORT33="$FIXgfs_mos/mdl_gfsmxmntd84.10010331.$cycle"
export FORT34="$FIXgfs_mos/mdl_gfscigcld.04010930.$cycle"
export FORT35="$FIXgfs_mos/mdl_gfscigcld.10010331.$cycle"
export FORT36="$FIXgfs_mos/mdl_gfspopqpf84.04010930.$cycle"
export FORT37="$FIXgfs_mos/mdl_gfspopqpf84.10010331.$cycle"
export FORT38="$FIXgfs_mos/mdl_gfsvisobv.04010930.$cycle"
export FORT39="$FIXgfs_mos/mdl_gfsvisobv.10010331.$cycle"
export FORT40="$FIXgfs_mos/mdl_gfsptype84.09010831.$cycle"
export FORT41="$FIXgfs_mos/mdl_gfsmtsnow.09010831.$cycle"
export FORT42="$FIXgfs_mos/mdl_gfspopc.04010930.$cycle"
export FORT43="$FIXgfs_mos/mdl_gfspopc.10010331.$cycle"
export FORT20="$FIXgfs_mos/mdl_gfspopo.04010930.$cycle"
export FORT21="$FIXgfs_mos/mdl_gfspopo.10010331.$cycle"
export FORT50="$FIXgfs_mos/mdl_gfsgust.04010930.$cycle"
export FORT51="$FIXgfs_mos/mdl_gfsgust.10010331.$cycle"
export FORT52="$FIXgfs_mos/mdl_gfscigopqcld.04010930.$cycle"
export FORT53="$FIXgfs_mos/mdl_gfscigopqcld.10010331.$cycle"
export FORT49="mdl_gfsmos.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfseval.cn.$cycle >> $pgmout 2>errfile
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
export FORT26="$FIXcode/mdl_station.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT28="$FIXgfs_mos/mdl_gfspost.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT45="$FIXcode/mdl_conststa"
export FORT47="$FIXgfs_mos/mdl_threshold"
export FORT49="mdl_gfsmos.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfspost.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended 

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_gfsmos.$cycle $COMOUT
  cpfs mdl_gfsobs.$cycle $COMOUT
  cpfs gfsmodel.$DAT $COMOUT/mdl_gfsprdpkd.$cycle
  cpfs pkobs.$DAT $COMOUT/mdl_gfsobspkd.$cycle
fi
ecflow_client --event metar_fcst_done
#######################################################################
echo MDLLOG: `date` - Job gfsmos_metar_fcst has ended.
#######################################################################
