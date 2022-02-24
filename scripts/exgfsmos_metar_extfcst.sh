#!/bin/sh
#######################################################################
#  Job Name: exgfsmos.sh.ecf (formerly exmrfmos.sh.sms)
#  Purpose: To run all steps necessary to create extended-range GFS MOS
#           fcsts
#  Remarks:
#  HISTORY: May 16, 2000         - new job for MRF MOS2000
#           July 5, 2000         - updated for PoP/QPF elements
#           Aug 30, 2000  RLA    - implemented cool temps
#           Sep 13, 2000 MCE/MAS - implemented cool PoP/QPF and
#                                  added consistency check for 24-hr PoP
#           Sep 27, 2000         - implemented Ptype and cool clouds
#           Feb  6, 2001  RLA    - implemented warm season clouds
#           Mar 22, 2001  MAS    - implemented bufr
#           Apr 17, 2001  RLA    - implemented spring and summer tsvr
#           Aug 15, 2001 RLA/JCM - implemented winter tsvr
#           Aug 24, 2001 RLA/MCE - implemented Air Force message
#           Aug 31, 2001  RLA    - implemented updated cool season mxmntd
#           Oct 02, 2001 MCE/RLA - added grib steps for CONUS/AK
#           Jan 09, 2002  RLC    - changed name of mdl_mos2grd1081.tbl to
#                                  mdl_mos2grd.tbl when station number was
#                                  upped to 1432.
#           Apr 23, 2002  RLC    - added step to create FECN21, Canadian
#                                  max/min text message
#           Jun 12, 2002  RLC    - added dbnet alerts to get files to TGFTP
#           Jul 16, 2002  MCE    - added climo to constant file, added
#                                  constant file to mex message step
#           Aug 01, 2002  JCM    - updated for new grb2mdlp and mdl_gridlst
#           Aug 20, 2002  RLC    - added step to archive Nam tsvr @ 00Z
#           Aug 23, 2002  MCE    - implemented warm and cool wind speed
#           AUG 20, 2003  RLC    - GFS TRANSTITION - merged GFS and MRF
#                                  processing into one GFS paradigm.  At
#                                  this time, the mrfmos script will do
#                                  the MEX forecasts and products.  Both
#                                  gfsmos and mrfmos jobs will write to
#                                  gfsmos random access file.  The archiving
#                                  of the GFS MOS Forecasts happens here.
#                                  We'll now run this script 4 times daily
#                                  so we can archive all 4 cycles to 384h.
#           Mar 10, 2004  JCM    - Nam and GFS gridded constants files
#                                  have been merged into one file; this
#                                  required renaming the file on unit 44.
#           May  4, 2004  RLC    - Removed the dependency on 6Z obs.
#                                  Changed the obsprep to use 3Z obs instead.
#           Nov 15, 2004  RLC    - Changed BUFR dbnet alert to go NTC.
#           DEC 13, 2004 JCM  - GRIDDED MOS:  Stripped out TSTM stuff, this
#                               script now only runs through the
#                               post-processor.
#           Sep 13, 2005 RLC  - Added hard stop if short-range random
#                               access file isn't found.
#           Apr 26, 2006 JCM  - Added wind gusts to EQNEVAL
#           Jun 26, 2006 RLC  - Took out original 12-hr max wind
#                               eqns and processing.  Now the value comes
#                               from post-processing the hourly winds.
#           Feb 28, 2007 RLC  - Added opaque cloud equations.
#           Aug 15, 2007 RLC  - Added new code seq2ra.  The PRISM normals
#                               are interpolated to stations in U201.
#                               This new code puts them in the ra file.
#           Oct 07, 2009 JCM  - Added new PTYPE for NDGD support.
#                               Snow now goes out an extra 24h.
#           Dec 03, 2012 EFE  - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Apr 04, 2014 EFE  - Added copying of gfsxmodel.$DAT to $COMOUT
#                               as mdl_gfsxprdpkd.$cycle.
#           Feb 10, 2016 SDS  - Configured for MPMD
#
#######################################################################
#
PS4='${PMI_FORK_RANK} $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_metar_extfcst

set -x

cd $DATA/metar
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

###########################################################################
#
#    THIS JOB USES THE RANDOM ACCESS FILE FIRST CREATED IN THE
#    EXECUTION OF EXGFSMOS_METAR_FCST.  CHECK IF THE FILE MDL_GFSMOS.TXXZ
#    EXISTS IN COM/GFS.  IF IT DOES, COPY THE FILE TO THE WORK SPACE.
#    IF IT DOES NOT EXIST, THE SCRIPT WILL ABORT.  GFSMOS_METAR_EXTFCST
#    WILL NOT WORK UNLESS EXGFSMOS_METAR_FCST HAS ALREADY RUN SUCCESSFULLY.
#
############################################################################
#
if [ ! -f $COMIN/mdl_gfsmos.$cycle ]
     then echo 'need successful run of gfsmos_metar_fcst to run properly' >> $pgmout
             export err=1;err_chk
fi

cpreq $COMIN/mdl_gfsmos.$cycle .

######################################################################
#  COPY THE MDL GFS MODEL FILES FROM COM
#######################################################################
cpreq $COMIN/mdl_gfspkd47.$cycle pkgfsraw.$DAT
cpreq $COMIN/mdl_gfsxpkd47.raw.$cycle pkgfsxraw.$DAT
#cp $COMIN/mdl_gfsxpkd47.$cycle pkgfsxraw.$DAT

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
elif test $cyc -eq '12'
then
 obhr1=15
 cp $COMINhry_mos/sfctbl.$obhr1 sfctbl.$obhr1
 if [ $? -ne 0 ]; then
    msg="WARNING: OBSERVATIONS NOT AVAILABLE FOR 15Z. USING SECONDARY EQUATIONS"
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
export FORT23="pkgfsraw.$DAT"
export FORT24="pkgfsxraw.$DAT"
export FORT26="$FIXcode/mdl_station.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxprd.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_griddedconstants"
export FORT45="$FIXcode/mdl_conststa"
export FORT60="gfsxmodel.$DAT"
startmsg
$EXECcode/mdl_mospred < $PARMgfs_mos/mdl_gfsxpredmdl.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  First use of MOSPRED ended


#######################################################################
#
#    SECOND EXECUTION OF PROGRAM MOSPRED
#    MOSPRED - USED TO CREATE OBSERVED PREDICTORS FROM THE MDL
#              OBSERVATIONAL TABLES.
#  NOTE:  Right now this produces lots of errors because we're using
#         3hr obs, but asking for 6.  This will happen until we redo
#         ptype and clouds with 3hr obs.
#######################################################################

echo MDLLOG: `date` - begin job MOSPRED - CREATE OBSERVATIONAL PREDICTORS
export pgm=mdl_mospred
. prep_step
export FORT10="ncepdate"
export FORT80="pkobs.$DAT"
export FORT26="$FIXcode/mdl_station.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxprd.obs"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT61="mdl_gfsxobs.$cycle"
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
export FORT23="mdl_gfsxobs.$cycle"
export FORT24="gfsxmodel.$DAT"
export FORT26="$FIXcode/mdl_station.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT28="$FIXcode/mdl_predtofcst"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="$FIXgfs_mos/mdl_gfsxmxmntd.04010930.$cycle"
export FORT31="$FIXgfs_mos/mdl_gfsxmxmntd.10010331.$cycle"
export FORT32="$FIXgfs_mos/mdl_gfsxpopqpf.04010930.$cycle"
export FORT33="$FIXgfs_mos/mdl_gfsxpopqpf.10010331.$cycle"
export FORT34="$FIXgfs_mos/mdl_gfsxcld.04010930.$cycle"
export FORT35="$FIXgfs_mos/mdl_gfsxcld.10010331.$cycle"
export FORT36="$FIXgfs_mos/mdl_gfsxwind.04010930.$cycle"
export FORT37="$FIXgfs_mos/mdl_gfsxwind.10010331.$cycle"
export FORT38="$FIXgfs_mos/mdl_gfsxptype.09010831.$cycle"
export FORT39="$FIXgfs_mos/mdl_gfsxmtsnow.09010831.$cycle"
export FORT50="$FIXgfs_mos/mdl_gfsxgust.04010930.$cycle"
export FORT51="$FIXgfs_mos/mdl_gfsxgust.10010331.$cycle"
export FORT52="$FIXgfs_mos/mdl_gfsxopqcld.04010930.$cycle"
export FORT53="$FIXgfs_mos/mdl_gfsxopqcld.10010331.$cycle"
export FORT54="$FIXgfs_mos/mdl_gfsptype192.09010831.$cycle"
export FORT49="mdl_gfsmos.$cycle"
startmsg
$EXECcode/mdl_eqneval < $PARMgfs_mos/mdl_gfsxeval.cn.$cycle >> $pgmout 2>errfile
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
export FORT28="$FIXgfs_mos/mdl_gfsxpost.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT45="$FIXcode/mdl_conststa"
export FORT47="$FIXgfs_mos/mdl_threshold"
export FORT49="mdl_gfsmos.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfspost.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended

#######################################################################
#
#    PROGRAM SEQ2RA - WRITES VECTOR SEQUENTIAL TO STATION RANDOM ACCESS
#      THIS GETS THE PRISM NORMALS FROM THE U201 OUTPUT AND WRITES 
#      THEM TO THE FORECAST FILE FOR USE BY MEX CODE.
#
#######################################################################

echo MDLLOG: `date` - begin job SEQ2RA - PACKS PRISM NORMALS
export pgm=mdl_seq2ra
. prep_step
export FORT26="$FIXcode/mdl_station.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT20="gfsxmodel.$DAT"
export FORT49="mdl_gfsmos.t${cyc}z"
startmsg
$EXECcode/mdl_seq2ra < $PARMgfs_mos/mdl_seq2ra.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  SEQ2RA ended

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_gfsmos.$cycle $COMOUT
  cpfs mdl_gfsxobs.$cycle $COMOUT
  cpfs gfsxmodel.$DAT $COMOUT/mdl_gfsxprdpkd.$cycle
  cpfs pkobs.$DAT $COMOUT/mdl_gfsxobspkd.$cycle
fi

#######################################################################
echo MDLLOG: `date` - Job gfsmos_metar_extfcst has ended.
#######################################################################
