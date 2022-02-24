#!/bin/sh
##########################################################################
#  Job Name: exgfsmos_station_extprdgen.sh.ecf 
#  Purpose: To run all steps necessary to create extended-range GFS-based
#           MOS station-based products.  It creates all of our text,
#           BUFR, and GRIB1 products for the METAR, Pacific, coop, and
#           rfc sites.
#  Remarks: This script is kicked off when all 5 of the extended forecast 
#           jobs have completed (METAR, GOE, COOPMESO, TSTM, PACIFIC). 
#           It runs at all 4 cycles.
#
#  HISTORY: Jun 13, 2005      - new job for Gridded MOS
#           Sep 13, 2005      - added 12Z versions of MEX and FECN21
#           Oct 11, 2005      - added 12Z new MEX BUFR
#           Feb 07, 2006      - changed text alerts to go NTC
#           Mar 02, 2006      - added 40km tstm. 
#                               Added archiving of 40 km and 20 km tstm 
#                               forecasts
#           Aug 15, 2007      - changed unit number of gfsmos file in mex
#                               run because we now have the PRISM normals
#                               in the forecast file too and it doesn't 
#                               work as unit 48 or 49.
#           Mar  6, 2008      - Added steps to get 47km AK thunderstorms
#                               set to stations and merged into text
#                               and BUFR files.  Also added archive step
#                               for AK 47km thunderstorms.
#           APR 16, 2008      - Changed RAMERGE step fix file from
#                               mdl_gfsxramerge.$cycle to mdl_pacxramerge
#                               because we stomped on grdprdgen.
#           Dec  9, 2008      - Removed Eta TSVR archiving.  This is now 
#                               done in the NAM MOS script.
#           Dec 11, 2009      - added archiving of 80 km tstm forecasts;
#                               removed archiving of 48 km tsvr fcsts.
#           Dec 03, 2012      - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           May 08, 2013      - Added step to create and save sequential
#                               file for 20km MOS convection.
#           Feb 10, 2016      - Configured for MPMD
#           Jun 07, 2019      - Removed all GRIB1 processing (all
#                               processes that used mdl_ra2grib) for
#                               legacy data that was sent to COMOUT
#                               and TGFTP.
##########################################################################
#
PS4='station_extprdgen $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_station_extprdgen

set -x

cd $DATA/station
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"


#######################################################################
#  COPY THE MDL FORECAST FILES FROM COM
#    6/2005 - We need the METAR, COOPRFCMESO, TSVR and PACIFIC files
#    3/2008 - Also need the 47 km AK thunderstorms, and the file where
#             the CONUS and Pacific stations for all elements and AK
#             thunderstorms were merged into one.
#######################################################################
cpreq $COMIN/mdl_gfsmos.$cycle mdl_gfsmos.$cycle
cpreq $COMIN/mdl_gfscpmos.$cycle mdl_gfscpmos.$cycle
cpreq $COMIN/mdl_gfstsvr40.$cycle mdl_gfstsvr40.$cycle
cpreq $COMIN/mdl_gfstsvrak47.$cycle mdl_gfstsvrak47.$cycle
cpreq $COMIN/mdl_gfstsvrak47atsta.$cycle mdl_gfstsvrak47atsta.$cycle
cpreq $COMIN/mdl_gfsmergemos.$cycle mdl_gfsmergemos.$cycle
if [ $cyc -eq '00' -o $cyc -eq '12' ]
then
cpreq $COMIN/mdl_pacgfsmos.$cycle mdl_pacgfsmos.$cycle
fi

#######################################################################
#  WE ARCHIVE AT ALL 4 CYCLES.  SO ONLY GO THROUGH PRODUCT GENERATION
#  PART OF SCRIPT FOR 00 AND 12Z.  FOR 06/18Z, SKIP TO ARCHIVING PART
#  AT THE END OF SCRIPT.
#   9/2005 - ADDED 12Z MEX AND FECN21 TEXT PRODUCTS. 
#######################################################################

if [ $cyc -eq '00' -o $cyc -eq '12' ]
then

########################################################################
#
#    PROGRAM FCSTPOST - USED TO COMBINE TSVR & MOS FORECASTS
#     3/2006 - this is the 40km stuff and is available at 00 and 12Z
#######################################################################

echo MDLLOG: `date` - begin job FCSTPOST - COMBINE TSVR and MOS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXcode/mdl_station.lst"
export FORT27="$FIXgfs_mos/mdl_mos2grd_40.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxtsvr40comb.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT48="mdl_gfstsvr40.$cycle"
export FORT49="mdl_gfsmos.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfspostcomb.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended

#######################################################################
# COPY FILES TO COM 
#######################################################################

 if test $SENDCOM = 'YES'
 then
    cpfs mdl_gfsmos.$cycle $COMOUT
 fi

########################################################################
#    PROGRAM FCSTPOST - USED TO COMBINE TSVR & MOS FORECASTS
#     3/2008 - this is the AK 47km stuff and is available at 00 and 12Z
#######################################################################

echo MDLLOG: `date` - begin job FCSTPOST - COMBINE TSVR and MOS
export pgm=mdl_fcstpost
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_metarpacsta.lst"
export FORT27="$FIXgfs_mos/mdl_mos2grd_ak47.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxtsvrak47comb.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT48="mdl_gfstsvrak47.$cycle"
export FORT49="mdl_gfstsvrak47atsta.$cycle"
startmsg
$EXECcode/mdl_fcstpost < $PARMgfs_mos/mdl_gfspostcomb.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  FCSTPOST ended

#######################################################################
#  CODE RAMERGE
#   COMBINE THE US AND ALASKA TSTORM SITES INTO 1 RANDOM ACCES FILE.
#   THIS FILE WILL BE READ BY THE TEXT AND BUFR RUNS
#######################################################################
echo MDLLOG: `date` - begin job RAMERGE

export pgm=mdl_ramerge
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_metarpacsta.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT28="$FIXgfs_mos/mdl_pacxramerge.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT36="mdl_gfsmos.$cycle"
export FORT44="mdl_gfstsvrak47atsta.$cycle"
export FORT49="mdl_gfsmergemos.$cycle"
$EXECcode/mdl_ramerge < $PARMgfs_mos/mdl_ramergera_ext.cn.$cycle >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAMERGE ended

#######################################################################
# COPY FILES TO COM 
#######################################################################

 if test $SENDCOM = 'YES'
 then
    cpfs mdl_gfstsvrak47atsta.$cycle $COMOUT
    cpfs mdl_gfsmergemos.$cycle $COMOUT
 fi

#######################################################################
#  FIRST CREATE ALL OF OUR TEXT PRODUCTS, COPY THEM TO COM AND SEND
#  THEM OUT
#######################################################################

#######################################################################
# GFSMEXTX
# EXTENDED-RANGE GFS MOS MESSAGE CODE
# HEADERS: FEPA20, FEUS21-26, FEAK37-39 KWNO, MEXXXX
# runs at 00 and 12Z
#######################################################################

export pgm=mdl_gfsmextx
. prep_step
export FORT10="ncepdate"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT45="$FIXcode/mdl_conststa"
export FORT38="mdl_gfsmergemos.$cycle"
export FORT60="mdl_gfsmex.$cycle"
export FORT65="mdl_gfsmex.tran"
startmsg
$EXECcode/mdl_gfsmextx < $PARMgfs_mos/mdl_gfsmextx.dat >> $pgmout 2>errfile
export err=$?

#######################################################################
# SECOND RUN OF GFSMEXTX
# CREATE AIR FORCE MRF MOS MESSAGE 
# HEADERS: FEPA30, FEUS30, FEAK30, FECA30 KWNO MEXFXX
#  Note:  This message is only produced at 00Z
#######################################################################

if test $cyc -eq '00'
then

export pgm=mdl_gfsmextx
. prep_step
export FORT10="ncepdate"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT45="$FIXcode/mdl_conststa"
export FORT38="mdl_gfsmergemos.$cycle"
export FORT60="mdl_gfsafmex.$cycle"
export FORT65="mdl_gfsafmex.tran"
startmsg
$EXECcode/mdl_gfsmextx < $PARMgfs_mos/mdl_gfsafmextx.dat >> $pgmout 2>errfile
export err=$?

fi

#############################################
#  GENERATE THE FECN21 CANADIAN BULLETIN
#  HEADER: FECN21 KWNO MEXCND
# runs at 00 and 12Z
#############################################

export pgm="mdl_fecn21tx"
. prep_step
export FORT10="ncepdate" 
export FORT27="$FIXcode/mdl_station.tbl" 
export FORT45="$FIXcode/mdl_conststa" 
export FORT48="mdl_gfsmos.$cycle" 
export FORT60="mdl_fecn21.$cycle" 
export FORT65="mdl_fecn21.tran" 
startmsg
$EXECcode/mdl_fecn21tx < $PARMgfs_mos/mdl_fecn21tx.dat >>$pgmout 2>errfile 
export err=$?;err_chk

#######################################################################
# GFSMCXTX
# EXTENDED-RANGE GFS MOS COOP MESSAGE CODE
# HEADER: FEUS10 KWNO MCXUSA
# runs at 00 and 12Z
#######################################################################

export pgm=mdl_gfsmcxtx
. prep_step
export FORT10="ncepdate"
export FORT27="$FIXgfs_mos/mdl_cooprfcmnsta.tbl"
export FORT48="mdl_gfscpmos.$cycle"
export FORT60="mdl_gfsmcx.$cycle"
export FORT65="mdl_gfsmcx.tran"
startmsg
$EXECcode/mdl_gfsmcxtx < $PARMgfs_mos/mdl_gfsmcxtx.dat >> $pgmout 2>errfile
export err=$?; err_chk

#######################################################################
# RFCFTPTX - CREATES RFC TEXT AND TRANS FILES
# HEADERS: FOUS12 KWNO RFCXXX
#
#  FOR THE 00Z CYCLE ONLY, RUN RFC TEXT MESSAGE. 
#  THE 12Z RFCFTP IS RUN/DISSEMINATED IN STATION_PRDGEN (SR SCRIPT)
#######################################################################
if test $cyc -eq '00'
then

export pgm=mdl_rfcftptx
. prep_step

export FORT10="ncepdate"
export FORT27="$FIXgfs_mos/mdl_cooprfcmnsta.tbl.shef"
export FORT36="mdl_gfsmos.t00z"
export FORT38="mdl_gfscpmos.t00z"
export FORT60="mdl_rfcftp.$cycle"
export FORT65="mdl_rfcftp.tran"
startmsg
$EXECcode/mdl_rfcftptx < $PARMgfs_mos/mdl_rfcftptx.dat >> $pgmout 2>errfile
export err=$?; err_chk
fi

#######################################################################
# COPY FILES TO COM & SEND OUT MESSAGE
#######################################################################

if test $SENDCOM = 'YES'
then
   cpfs mdl_gfsmos.$cycle $COMOUT
   cpfs mdl_gfsmcx.$cycle $COMOUT
   cpfs mdl_gfsmcx.tran $COMOUTwmo/gfsmcx.tran.$filenametask
   cpfs mdl_gfsmex.$cycle $COMOUT
   cpfs mdl_gfsmex.tran $COMOUTwmo/gfsmex.tran.$filenametask
   cpfs mdl_fecn21.$cycle $COMOUT
   cpfs mdl_fecn21.tran $COMOUTwmo/fecn21.tran.$filenametask
    if test $cyc -eq '00'
    then
     cpfs mdl_gfsafmex.$cycle $COMOUT
     cpfs mdl_gfsafmex.tran $COMOUTwmo/gfsafmex.tran.$filenametask
     cpfs mdl_rfcftp.$cycle $COMOUT
     cpfs mdl_rfcftp.tran $COMOUTwmo/rfcftp.tran.$filenametask
    fi
fi

if test $SENDDBN_NTC = 'YES'
then
   $DBNROOT/bin/dbn_alert TEXT mrf $job $COMOUTwmo/gfsmcx.tran.$filenametask
   $DBNROOT/bin/dbn_alert TEXT mrf $job $COMOUTwmo/gfsmex.tran.$filenametask
   $DBNROOT/bin/dbn_alert TEXT mrf $job $COMOUTwmo/fecn21.tran.$filenametask
   if test $cyc -eq '00'
   then
      $DBNROOT/bin/dbn_alert TEXT mrf $job $COMOUTwmo/gfsafmex.tran.$filenametask
      $DBNROOT/bin/dbn_alert TEXT mrf $job $COMOUTwmo/rfcftp.tran.$filenametask
   fi
fi

if test $SENDDBN = 'YES'
then
   $DBNROOT/bin/dbn_alert MDLFCST GFSXCPMOS $job $COMOUT/mdl_gfsmcx.$cycle
   $DBNROOT/bin/dbn_alert MDLFCST MRFMOSTXT $job $COMOUT/mdl_gfsmex.$cycle
     if test $cyc -eq '00'
     then
      $DBNROOT/bin/dbn_alert MDLFCST MRFMOSAFTXT $job $COMOUT/mdl_gfsafmex.$cycle
     fi
fi

#########################################################
#   Generate NEW GFSX MOS BUFR message
#   This runs at both 00Z and 12Z
#########################################################
export pgm="mdl_mos2bufr"
. prep_step
export FORT10="ncepdate"
export FORT25="$FIXgfs_mos/mdl_mexbufr.dat"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT40="mdl_gfsmergemos.$cycle"
export FORT60="mdl_mexbufr.xtrn"
startmsg
$EXECcode/mdl_mos2bufr < $PARMgfs_mos/mdl_mexbufr.cn.$cycle >> $pgmout 2>errfile
export err=$?;err_chk


if test $SENDCOM = 'YES'
then
   cpfs mdl_mexbufr.xtrn $COMOUTwmo/mexbufr.xtrn.$filenametask
   cpfs mdl_mexbufr.xtrn $COMOUT/mdl_mexbufr.xtrn.$cycle
fi

if test $SENDDBN_NTC = 'YES'
then
   $DBNROOT/bin/dbn_alert GRIB_LOW mrf $job $COMOUTwmo/mexbufr.xtrn.$filenametask
fi
#
fi # fi for 00/12 product generation loop
#
#############################################################
#  AT ALL 4 CYCLES WE NEED TO ARCHIVE THE STATION FORECASTS
#############################################################

#######################################################################
#  CODE RAMERGE
#  COMBINE THE PACIFIC AND US SITES INTO 1 SEQUENTIAL FILE THAT WILL
#  BE SAVED AS THE ARCHIVE.  ALSO ADD IN THE ALASKA THUNDERSTORMS (BUT 
#  WE ONLY ARCHIVE AT STATIONS THE AK THUNDERSTORMS WE PUT IN PRODUCTS).
#    NOTE: (THE REASON WE DON'T JUST USE THE GFSMERGEMOS FILE IS
#           BECAUSE GFSMERGEMOS ONLY CONTAINS FORECASTS THAT GO IN 
#           PRODUCTS AND WE ARCHIVE A LOT MORE THAN THAT.)
#    NOTE:  UNIT 36 IS ONLY THERE FOR 00 AND 12Z SO THE 06/18 CN FILE
#           DOESN'T HAVE A UNIT 48 IN IT.
#######################################################################
echo MDLLOG: `date` - begin job RAMERGE

export pgm=mdl_ramerge
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_metarpacsta.lst"
export FORT27="$FIXcode/mdl_station.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsarch.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT35="mdl_gfsmos.$cycle"
export FORT36="mdl_gfstsvrak47atsta.$cycle"
export FORT37="mdl_pacgfsmos.$cycle"
export FORT60="mdl_gfsmossq.$cycle"
startmsg
$EXECcode/mdl_ramerge < $PARMgfs_mos/mdl_ramergesq.cn.$cycle >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAMERGE ended

#######################################################################
# RA2MDLP - ARCHIVE 40KM TSVR FORECASTS
# CONVERT RANDOM ACCESS TO SEQUENTIAL MDL_PACK
#   6 - 192 HOURS 00/12Z, 6 - 84 HOURS 06/18Z
#   *** THIS STEP WILL BE MOVED TO THE GRIDDED_PRDGEN SCRIPT WHEN
#          IT BECOMES OPERATIONAL ***
#######################################################################

export pgm="mdl_ra2mdlp"
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXcode/mdl_tsvr40sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr40sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfstsvr40arch.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT38="mdl_gfstsvr40.$cycle"
export FORT66="mdl_gfstsvr40mossq.$cycle"
startmsg
$EXECcode/mdl_ra2mdlp < $PARMcode/mdl_ra2mdlp.cn >> $pgmout 2>errfile
export err=$?;err_chk

#######################################################################
# RA2MDLP - ARCHIVE 20KM TSVR FORECASTS
# CONVERT RANDOM ACCESS TO SEQUENTIAL MDL_PACK
#   6 - 36 HOURS 00/06/12/18Z
#   *** THIS STEP WILL BE MOVED TO THE GRIDDED_PRDGEN SCRIPT WHEN
#          IT BECOMES OPERATIONAL ***
#######################################################################

cpreq $COMIN/mdl_gfstsvr20.$cycle mdl_gfstsvr20.$cycle

export pgm="mdl_ra2mdlp"
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_tsvr20sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr20sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfstsvr20arch.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT38="mdl_gfstsvr20.$cycle"
export FORT66="mdl_gfstsvr20mossq.$cycle"
startmsg
$EXECcode/mdl_ra2mdlp < $PARMcode/mdl_ra2mdlp.cn >> $pgmout 2>errfile
export err=$?;err_chk

#######################################################################
# RA2MDLP - ARCHIVE 20KM CONV FORECASTS
# CONVERT RANDOM ACCESS TO SEQUENTIAL MDL_PACK
#   6 - 36 HOURS 00/06/12/18Z
#   *** THIS STEP WILL BE MOVED TO THE GRIDDED_PRDGEN SCRIPT WHEN
#          IT BECOMES OPERATIONAL ***
#######################################################################

cpreq $COMIN/mdl_gfsconv20.$cycle mdl_gfsconv20.$cycle

export pgm="mdl_ra2mdlp"
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_tsvr20sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr20sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsconv20arch.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT38="mdl_gfsconv20.$cycle"
export FORT66="mdl_gfsconv20mossq.$cycle"
startmsg
$EXECcode/mdl_ra2mdlp < $PARMcode/mdl_ra2mdlp.cn >> $pgmout 2>errfile
export err=$?;err_chk

if test $SENDCOM = 'YES'
then
  cpfs mdl_gfsconv20mossq.$cycle $COMOUT
fi

#######################################################################
# RA2MDLP - ARCHIVE 80KM TSVR FORECASTS
# CONVERT RANDOM ACCESS TO SEQUENTIAL MDL_PACK
#   6 - 84 HOURS 00/06/12/18Z
#   *** THIS STEP WILL BE MOVED TO THE GRIDDED_PRDGEN SCRIPT WHEN
#          IT BECOMES OPERATIONAL ***
#######################################################################

cpreq $COMIN/mdl_gfstsvr80.$cycle mdl_gfstsvr80.$cycle

export pgm="mdl_ra2mdlp"
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_tsvr80sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvr80sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfstsvr80arch.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT38="mdl_gfstsvr80.$cycle"
export FORT66="mdl_gfstsvr80mossq.$cycle"
startmsg
$EXECcode/mdl_ra2mdlp < $PARMcode/mdl_ra2mdlp.cn >> $pgmout 2>errfile
export err=$?;

#######################################################################
# RA2MDLP - ARCHIVE 47KM ALASKA TSVR FORECASTS
# CONVERT RANDOM ACCESS TO SEQUENTIAL MDL_PACK
#######################################################################

export pgm="mdl_ra2mdlp"
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_tsvrak47sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvrak47sta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfstsvrak47arch.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT38="mdl_gfstsvrak47.$cycle"
export FORT66="mdl_gfstsvrak47mossq.$cycle"
startmsg
$EXECcode/mdl_ra2mdlp < $PARMcode/mdl_ra2mdlp.cn >> $pgmout 2>errfile
export err=$?;err_chk

#######################################################################
# RA2MDLP
# CONVERT RANDOM ACCESS TO SEQUENTIAL MDL_PACK
# THIS IS THE ARCHIVING OF THE COOP FORECASTS
#######################################################################

export pgm="mdl_ra2mdlp"
. prep_step
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_cooprfcmnsta.lst"
export FORT27="$FIXgfs_mos/mdl_cooprfcmnsta.tbl"
export FORT28="$FIXgfs_mos/mdl_gfscparch.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT38="mdl_gfscpmos.$cycle"
export FORT66="mdl_gfscpmossq.$cycle"
startmsg
$EXECcode/mdl_ra2mdlp < $PARMcode/mdl_ra2mdlp.cn >> $pgmout 2>errfile
export err=$?;err_chk


#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_gfsmossq.$cycle $COMOUT
  cpfs mdl_gfstsvr40mossq.$cycle $COMOUT
  cpfs mdl_gfstsvr20mossq.$cycle $COMOUT
  cpfs mdl_gfstsvr80mossq.$cycle $COMOUT
  cpfs mdl_gfstsvrak47mossq.$cycle $COMOUT
  cpfs mdl_gfscpmossq.$cycle $COMOUT
fi

echo MDLLOG: `date` - Job exgfsmos_station_extprdgen has ended.
#######################################################################
