#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_station_prdgen.sh.ecf 
#  Purpose: To run all steps necessary to create short range GFS-based
#           MOS station-based products.  It creates all of our text,
#           BUFR, and GRIB1 products for the METAR, Pacific, coop, and
#           rfc sites.
#  Remarks: This script is kicked off when all 5 of the forecast jobs
#           have completed (METAR, GOE, COOPMESO, TSTM, PACIFIC). 
#
#  HISTORY: Jun 13, 2005      - new job for Gridded MOS
#           Feb  7, 2006      - changed text product alerts to go NTC
#           Mar  2, 2006      - added the 40km tstm forecasts so
#                               right now there's one run of U910
#                               to get 40km tstm forecasts @ sites
#                               and another to get 48km svr @ sites
#           Jul  7, 2006      - Removed old BUFR products
#           Mar  5, 2008      - Added steps to get 47km AK thunderstorms
#                               set to stations and merged into text
#                               and BUFR files
#           Dec 10, 2009      - Changed steps to put 80km svr @ sites
#                               as 48km tsvr is discontinued; changed
#                               tstm GRIB1 to use 40/80km instead of
#                               48km.
#           Dec 03, 2012  EFE - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Feb 04, 2016  SDS - Configured for MPMD
#           Jun 07, 2019  MNB - Removed all GRIB1 processing (all
#                               processes that used mdl_ra2grib) for
#                               legacy data that was sent to COMOUT
#                               and TGFTP. 
#######################################################################
#
set -x
PS4='station_prdgen $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_station_prdgen - RANK $ALPS_APP_PE


cd $DATA/station
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
#  COPY THE MDL FORECAST FILES FROM COM
#    6/2005 - We need the METAR, COOPRFCMESO, TSVR and PACIFIC files
#    3/2008 - Also need the 47 km AK thunderstorms
#######################################################################
cpreq $COMIN/mdl_gfsmos.$cycle mdl_gfsmos.$cycle
cpreq $COMIN/mdl_gfscpmos.$cycle mdl_gfscpmos.$cycle
cpreq $COMIN/mdl_gfstsvr80.$cycle mdl_gfstsvr80.$cycle
cpreq $COMIN/mdl_gfstsvr40.$cycle mdl_gfstsvr40.$cycle
cpreq $COMIN/mdl_gfstsvrak47.$cycle mdl_gfstsvrak47.$cycle
if [ $cyc -eq '00' -o $cyc -eq '12' ]
then
cpreq $COMIN/mdl_pacgfsmos.$cycle mdl_pacgfsmos.$cycle
fi

#######################################################################
#
#    PROGRAM FCSTPOST - USED TO COMBINE TSVR & MOS FORECASTS
#      3/2006 - THIS STEP GETS THE 40KM TSTM TO THE MOS SITES
#               FOR 6-, 12-, AND 24-HR TSTM FORECASTS.
#
#######################################################################

echo MDLLOG: `date` - begin job FCSTPOST - COMBINE TSVR and MOS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXcode/mdl_station.lst"
export FORT27="$FIXgfs_mos/mdl_mos2grd_40.tbl"
export FORT28="$FIXgfs_mos/mdl_gfstsvr40comb.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT48="mdl_gfstsvr40.$cycle"
export FORT49="mdl_gfsmos.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfspostcomb.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended

#######################################################################
#
#    PROGRAM FCSTPOST - USED TO COMBINE TSVR & MOS FORECASTS
#      3/2006 - THIS STEP GETS THE 48KM SVR TO THE MOS SITES
#               FOR 6- AND 12-HR (C/U)SVR FORECASTS.
#     12/2009 - CHANGED TO PUT THE 80KM SVR TO THE MOS SITES
#               FOR 6- AND 12-HR (C/U)SVR FORECASTS.
#
#######################################################################

echo MDLLOG: `date` - begin job FCSTPOST - COMBINE TSVR and MOS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXcode/mdl_station.lst"
export FORT27="$FIXgfs_mos/mdl_mos2grd_80.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsposttsvraw.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT48="mdl_gfstsvr80.$cycle"
export FORT49="mdl_gfsmos.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfspostcomb.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended

#######################################################################
#
#  PROGRAM RAINIT - INITIALIZES RANDOM ACCESS MOS FORECAST
#                   FILE WITH STATION CALL LETTERS,
#                   ELEVATION, LATITUDE, AND LONGITUDE
#
#  COPY THE RANDOM ACCESS TEMPLATE FILE FROM FIX
#######################################################################
cpreq $FIXcode/mdl_rafile_template mdl_gfsmergemos.$cycle

export pgm=mdl_rainit
. prep_step
echo MDLLOG: `date` - begin job RAINIT - INITIALIZE MOS FORECAST FILE
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_metarpacsta.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT49="mdl_gfsmergemos.$cycle"
startmsg
$EXECcode/mdl_rainit < $PARMcode/mdl_u351.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAINIT ended

#######################################################################
#  Make a copy of the station random access file created above.  We 
#  will then run fcstpost to assign the 47 km Alaska thunderstorms to
#  the Alaska stations
#######################################################################

cp mdl_gfsmergemos.$cycle mdl_gfstsvrak47atsta.$cycle

#######################################################################
#    PROGRAM FCSTPOST - USED TO COMBINE TSVR & MOS FORECASTS
#      3/2008 - THIS STEP GETS THE AK 47KM TSTM TO THE AK MOS SITES
#               FOR 6-, 12-, AND 24-HR TSTM FORECASTS.
#
#######################################################################

echo MDLLOG: `date` - begin job FCSTPOST - COMBINE TSVR and MOS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_metarpacsta.lst"
export FORT27="$FIXgfs_mos/mdl_mos2grd_ak47.tbl"
export FORT28="$FIXgfs_mos/mdl_gfstsvrak47comb.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT48="mdl_gfstsvrak47.$cycle"
export FORT49="mdl_gfstsvrak47atsta.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfspostcomb.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended

#######################################################################
#  CODE RAMERGE
#   COMBINE THE PACIFIC AND US SITES INTO 1 RANDOM ACCES FILE.
#   ALSO ADD IN THE ALASKA THUNDERSTORM STATIONS.
#    (THE 06/18Z RUNS DON'T HAVE THE PACIFIC FILE IN THEM)
#######################################################################
echo MDLLOG: `date` - begin job RAMERGE

export pgm=mdl_ramerge
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_metarpacsta.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT28="$FIXgfs_mos/mdl_pacramerge.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT46="mdl_gfsmos.$cycle"
export FORT44="mdl_gfstsvrak47atsta.$cycle"
export FORT48="mdl_pacgfsmos.$cycle"
export FORT49="mdl_gfsmergemos.$cycle"
$EXECcode/mdl_ramerge < $PARMgfs_mos/mdl_ramergera.cn.$cycle >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAMERGE ended

#######################################################################
# COPY FILES TO COM 
#######################################################################
if test $SENDCOM = 'YES'
then
  cpfs mdl_gfsmos.$cycle $COMOUT
  cpfs mdl_gfsmergemos.$cycle $COMOUT
  cpfs mdl_gfstsvrak47atsta.$cycle $COMOUT
fi

#######################################################################
#  FIRST CREATE ALL OF OUR TEXT PRODUCTS, COPY THEM TO COM AND SEND
#  THEM OUT
#######################################################################

#######################################################################
# GFSMAVTX
# SHORT-RANGE GFS MOS MESSAGE CODE
# WITH HEADERS FOPA20, FOUS21-26, FOAK37-39 KWNO MAVXXX
#######################################################################

export pgm=mdl_gfsmavtx
. prep_step
export FORT10="ncepdate"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT48="mdl_gfsmergemos.$cycle"
export FORT60="mdl_gfsmav.$cycle"
export FORT65="mdl_gfsmav.tran"
startmsg
$EXECcode/mdl_gfsmavtx < $PARMgfs_mos/mdl_gfsmavtx.dat.$cycle >> $pgmout 2>errfile
export err=$?; err_chk

#######################################################################
# SECOND RUN OF GFSMAVTX
# CREATE SHORT-RANGE AIR FORCE MOS MESSAGE
# WITH HEADERS FOPA30, FOUS30, FOAK30, FOCA30 KWNO MAVFXX
#######################################################################

export pgm=mdl_gfsmavtx
. prep_step
export FORT10="ncepdate"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT48="mdl_gfsmergemos.$cycle"
export FORT60="mdl_gfsafmav.$cycle"
export FORT65="mdl_gfsafmav.tran"
startmsg
$EXECcode/mdl_gfsmavtx < $PARMgfs_mos/mdl_gfsafmavtx.dat >> $pgmout 2>errfile
export err=$?; err_chk

#######################################################################
# THIRD RUN OF GFSMAVTX
# CREATE SHORT-RANGE PACIFIC MOS MESSAGE -- ONLY AT 00 & 12
# WITH HEADER FOPA21 KWNO MAVPA1
#######################################################################

if [ $cyc -eq '00' -o $cyc -eq '12' ]
then

export pgm=mdl_gfsmavtx
. prep_step
export FORT10="ncepdate"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT48="mdl_gfsmergemos.$cycle"
export FORT60="mdl_gfspacmav.$cycle"
export FORT65="mdl_gfspacmav.tran"
startmsg
$EXECcode/mdl_gfsmavtx < $PARMgfs_mos/mdl_gfspacmavtx.dat >> $pgmout 2>errfile
export err=$?; err_chk

fi

#######################################################################
# CREATE MARINE MOS GUIDANCE (MMG) MESSAGES
# WITH HEADERS FQPA20, FQUS21-26, FQAK37 KWNO MMGXXX
#######################################################################

export pgm=mdl_gfsmmgtx
. prep_step
export FORT10="ncepdate"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT48="mdl_gfsmos.$cycle"
export FORT60="mdl_gfsmmg.$cycle"
export FORT65="mdl_gfsmmg.tran"
startmsg
$EXECcode/mdl_gfsmmgtx < $PARMgfs_mos/mdl_gfsmmgtx.dat >> $pgmout 2>errfile
export err=$?; err_chk

#######################################################################
# GENERATE CANADIAN MAX/MIN BULLETIN AT 00 AND 12Z
# WITH HEADER FOCN20 KWNO 
#######################################################################

if [ $cyc -eq '00' -o $cyc -eq '12' ]
then

export pgm=mdl_focn20tx
. prep_step
export FORT10="ncepdate"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT48="mdl_gfsmos.$cycle"
export FORT60="mdl_focn20.$cycle"
export FORT65="mdl_focn20.tran"
startmsg
$EXECcode/mdl_focn20tx < $PARMgfs_mos/mdl_focn20tx.dat >> $pgmout 2>errfile
export err=$?; err_chk

fi

#######################################################################
# GFSMCGTX
# SHORT-RANGE GFS MOS COOP MESSAGE CODE
# HEADER: FOUS10 KWNO MCGUSA
#######################################################################

export pgm=mdl_gfsmcgtx
. prep_step
export FORT10="ncepdate"
export FORT27="$FIXgfs_mos/mdl_cooprfcmnsta.tbl"
export FORT48="mdl_gfscpmos.$cycle"
export FORT60="mdl_gfsmcg.$cycle"
export FORT65="mdl_gfsmcg.tran"
startmsg
$EXECcode/mdl_gfsmcgtx < $PARMgfs_mos/mdl_gfsmcgtx.dat >> $pgmout 2>errfile
export err=$?; err_chk

#######################################################################
# RFCFTPTX - CREATES RFC TEXT AND TRANS FILES
# HEADER: FOUS12 KWNO FTPXXX
#  FOR THE 12Z CYCLE ONLY, RUN RFC TEXT MESSAGE.  AT 00Z IT RUNS IN
#  EXGFSMOS_STATION_EXTPRDGEN.SH.SMS
#######################################################################

if test $cyc -eq '12'
then

#     copy the 00Z gfsmos random access file and   
#     gfscpmos random access file here from /com

   SEND_SHEF12="YES"
   if [[ -s $COMIN/mdl_gfsmos.t00z && -s $COMIN/mdl_gfscpmos.t00z ]]; then
      cpreq $COMIN/mdl_gfsmos.t00z mdl_gfsmos.t00z
      cpreq $COMIN/mdl_gfscpmos.t00z mdl_gfscpmos.t00z

      export pgm=mdl_rfcftptx
      . prep_step
      export FORT10="ncepdate"
      export FORT27="$FIXgfs_mos/mdl_cooprfcmnsta.tbl.shef"
      export FORT35="mdl_gfsmos.t12z"
      export FORT36="mdl_gfsmos.t00z"
      export FORT37="mdl_gfscpmos.t12z"
      export FORT38="mdl_gfscpmos.t00z"
      export FORT60="mdl_rfcftp.$cycle"
      export FORT65="mdl_rfcftp.tran"
      startmsg
      $EXECcode/mdl_rfcftptx < $PARMgfs_mos/mdl_rfcftptx.dat >> $pgmout 2>errfile
      export err=$?; err_chk
   else
      SEND_SHEF12="NO"
      msg="WARNING: MISSING 00z DATA. NO 12Z RFC SHEF BULLETIN WILL BE CREATED"
      postmsg "$jlogfile" "$msg"
   fi

fi

#######################################################################
# COPY FILES TO COM & SEND OUT MESSAGE
#   NOTE:  FOCN20 and PACMAV ONLY GO OUT AT 00 AND 12Z
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_gfsmav.$cycle $COMOUT
  cpfs mdl_gfsmav.tran $COMOUTwmo/gfsmav.tran.$filenametask
  cpfs mdl_gfsafmav.$cycle $COMOUT
  cpfs mdl_gfsafmav.tran $COMOUTwmo/gfsafmav.tran.$filenametask
  cpfs mdl_gfsmmg.$cycle $COMOUT
  cpfs mdl_gfsmmg.tran $COMOUTwmo/gfsmmg.tran.$filenametask
  cpfs mdl_gfsmcg.$cycle $COMOUT
  cpfs mdl_gfsmcg.tran $COMOUTwmo/gfsmcg.tran.$filenametask
    if [ $cyc -eq '00' -o $cyc -eq '12' ]
     then
      cpfs mdl_focn20.$cycle $COMOUT
      cpfs mdl_focn20.tran $COMOUTwmo/focn20.tran.$filenametask
      cpfs mdl_gfspacmav.$cycle $COMOUT
      cpfs mdl_gfspacmav.tran $COMOUTwmo/gfspacmav.tran.$filenametask
    fi
    if [ $cyc -eq 12 ] ; then
     cpfs mdl_rfcftp.$cycle $COMOUT
     cpfs mdl_rfcftp.tran $COMOUTwmo/rfcftp.tran.$filenametask
    fi
fi

if test $SENDDBN_NTC = 'YES'
then
   $DBNROOT/bin/dbn_alert TEXT gfs $job $COMOUTwmo/gfsmav.tran.$filenametask
   $DBNROOT/bin/dbn_alert TEXT gfs $job $COMOUTwmo/gfsafmav.tran.$filenametask
   $DBNROOT/bin/dbn_alert TEXT gfs $job $COMOUTwmo/gfsmmg.tran.$filenametask
   $DBNROOT/bin/dbn_alert TEXT gfs $job $COMOUTwmo/gfsmcg.tran.$filenametask
   if [ $cyc -eq '00' -o $cyc -eq '12' ]
   then
       $DBNROOT/bin/dbn_alert TEXT gfs $job $COMOUTwmo/gfspacmav.tran.$filenametask
       $DBNROOT/bin/dbn_alert TEXT gfs $job $COMOUTwmo/focn20.tran.$filenametask
   fi
   if [ $cyc -eq 12 ] ; then
      if [ "$SEND_SHEF12" != "NO" ]; then
         $DBNROOT/bin/dbn_alert TEXT gfs $job $COMOUTwmo/rfcftp.tran.$filenametask
      fi
   fi
fi

if test $SENDDBN = 'YES'
then
   $DBNROOT/bin/dbn_alert MDLFCST GFSMOSTXT $job $COMOUT/mdl_gfsmav.$cycle
   $DBNROOT/bin/dbn_alert MDLFCST GFSMOSAFTXT $job $COMOUT/mdl_gfsafmav.$cycle
   $DBNROOT/bin/dbn_alert MDLFCST GFSCPMOS $job $COMOUT/mdl_gfsmcg.$cycle
fi
 
#######################################################################
#  NOW CREATE ALL OF OUR BUFR PRODUCTS, COPY THEM TO COM AND SEND
#  THEM OUT
#######################################################################

#########################################################
#   Generate GFS MOS BUFR message 
#########################################################
export pgm="mdl_mos2bufr"
. prep_step
export FORT10="ncepdate"
export FORT25="$FIXgfs_mos/mdl_mavbufr.dat"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT40="mdl_gfsmergemos.$cycle"
export FORT60="mdl_mavbufr.xtrn"
startmsg
$EXECcode/mdl_mos2bufr < $PARMgfs_mos/mdl_mavbufr.cn.$cycle >> $pgmout 2>errfile
export err=$?;err_chk

if test $SENDCOM = 'YES'
then
   cpfs mdl_mavbufr.xtrn $COMOUTwmo/mavbufr.xtrn.$filenametask
   cpfs mdl_mavbufr.xtrn $COMOUT/mdl_mavbufr.xtrn.$cycle
fi

if [ "$SENDDBN_NTC" == 'YES' ]; then
   $DBNROOT/bin/dbn_alert GRIB_LOW gfs $job $COMOUTwmo/mavbufr.xtrn.$filenametask
fi

########################################################
#   Generate GFS MOS BUFR message - For PACIFIC SITES
#    RUN AT 00 AND 12 ONLY
#########################################################

if [ $cyc -eq '00' -o $cyc -eq '12' ]
then

export pgm="mdl_mos2bufr"
. prep_step
export FORT10="ncepdate"
export FORT25="$FIXgfs_mos/mdl_mavpacbufr.dat"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT40="mdl_pacgfsmos.$cycle"
export FORT60="mdl_mavpacbufr.xtrn"
startmsg
$EXECcode/mdl_mos2bufr < $PARMgfs_mos/mdl_mavpacbufr.cn.$cycle >> $pgmout 2>errfile
export err=$?;err_chk

  if test $SENDCOM = 'YES'
  then
     cpfs mdl_mavpacbufr.xtrn $COMOUTwmo/mavpacbufr.xtrn.$job
     cpfs mdl_mavpacbufr.xtrn $COMOUT/mdl_mavpacbufr.xtrn.$cycle
  fi

  if [ "$SENDDBN_NTC" == 'YES' ]; then
     $DBNROOT/bin/dbn_alert GRIB_LOW gfs $job $COMOUTwmo/mavpacbufr.xtrn.$job
  fi
fi

#######################################################################
#  ARCHIVING OF FORECASTS IS DONE IN GFSMOS_STATION_EXTPRDGEN
#######################################################################

echo MDLLOG: `date` - Job exgfsmos_station_prdgen has ended.
#######################################################################
