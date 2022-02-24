#!/bin/sh
##########################################################################
#  Job Name: exgfsmos_cogridded_extprdgen.merge.sh.ecf 
#  Purpose: To run all steps necessary to create extended-range GFS-based
#           gridded MOS fcsts for CONUS on the 2.5 km NDFD Grid
#  Remarks: This script is kicked off when the forecast jobs
#           METAR, GOE, COOPMESO, and TSTM have completed
#
#  HISTORY: Mar 03, 2008  RLC - new job for Alaska Gridded MOS.  Right
#                               now it just contains thunderstorm fcsts.
#           Mar 27, 2008  RLC - adding temperatures before we 
#                               implement for the first time.
#                               Note:  the sleep command is included to
#                               delay dissemination time.  As more fields
#                               are added the sleep time will decrease to
#                               minimize the impact on the future 
#                               dissemination times.
#           Sep 26, 2008  RLC - adding winds, POPs, and sky. POP and 
#                               sky have goe-based first guesses, 
#                               wind uses dmo. To be implemented 12/2008
#           Dec 18, 2009  GAW - adding QPF and snow.  To be
#                               implemented 1/2010, but snow and
#                               qpf grids will not be sent to the
#                               SBN yet.
#           Feb 18, 2010  EFE - adding QPF and snow to TOCGRIB2 file
#                               for transmission over SBN. To be
#                               implemented 3/30/2010.
#           Jan  7, 2011  EFE - New job for 2.5 km CONUS Gridded MOS. This
#                               script is adapted from Alaska extprdgen
#                               because Alaska is currently using U155
#                               version 9.
#           Feb 08, 2011  EFE - Updated section of the script that
#                               creates GRIB2 files. Because of
#                               current TOC limitations with file
#                               transmission sizes, we will be
#                               creating 3 sets of data that will be
#                               described below. More information
#                               is contained in that part of the script.
#           Mar 31, 2011  EFE - Added section after GRIDPOST to check
#                               for HRQPF GRIB2 files. If available,
#                               these files will be used as official
#                               products and alerted; if not, the
#                               regular GMOS POP/QPF files will be
#                               used.
#           Nov 08, 2012  EFE - Added dbn_alert commands for superheaded
#                               element GRIB2 files in $PCOM/
#           Nov 15, 2012  EFE - Added dbn_alert command for superheaded
#                               PTSTM03 GRIB2 file for 00Z only.
#           Nov 19, 2012  EFE - Turn off dbn alerts for non-headed 2.5KM
#                               CONUS GMOS GRIB2 files, using subtype string
#                               "GMOSXCO*"; Added "hr" to copy destination name
#                               of HR POP/QPF superheaded GRIB2 files to /pcom;
#                               Added dbn_alert command for superheaded PTSTM03
#                               GRIB2 file for 00Z only.
#           Dec 03, 2012  EFE - Transitioned to WCOSS (Linux). Changed
#                               all 'FORT  ' env vars to 'FORT  '. Changed all
#                               uses of aqm_smoke to tocgrib2super.
#           Sep 17, 2013  EFE - Uncommented dbn_alert commands for individual
#                               element GRIB2 files without WMO headers. These lines
#                               were uncommented by NCO on 4/22/2012 and this is
#                               update our version. Also, POP and QPF lines remain
#                               commented to stay consistent with what is in nwprod.
#           May 22, 2015  SDS - Added processing for extra-extended projections.
#           Jun  1, 2015  EFE - Added extra-extended range "xx" GRIB2 file creation and
#                               insert WMO super and individual headers. As of now,
#                               dbn_alert commands are set up to use substrings with
#                               "XX".
#           Oct  5, 2015  SDS - Clip disseminated GRIB2 data to be on the old grid
#                               after new grid broke in AWIPS2. Use SEND_OLD_GRID
#                               variable to trigger whether you want to clip.
#           Oct  7, 2015  GAW - Bug fix to regain any original Mesowest sites present
#                               in the new MADIS mesonet MOS forecasts.  Uses utility
#                               codes repackmeso and itdlp adjust station call letters
#                               prior to RAMERGE.
#           Feb 10, 2016  SDS - Configured for MPMD
#           Feb 11, 2016  SDS - Copy over coop RA file, since the SQ does not yet 
#                               exist when running the PRDGEN scripts MPMD.
#           Mar 10, 2016  SDS - Removed HRQPF dependency.
#           Mar 2018      GAW - Split from exgfsmos_cogridded_extprdgen.sh.ecf
#                               for parallel runs of GMOS element groups
#           Nov 2018      JLW - Added CIG and VIS
#           Jul 26, 2019  SDS - Removed dissemination of grids.    
#
#           NOTE: On approx. 12/13/12, NCO will begin routing 2.5KM CONUS GMOS
#                 GRIB2 files to TOC with superheaders and inidividual headers.
#                 Superheaders will be sents to TGFTP and inidividual headers
#                 will be sent to SBN/NOAAPORT.
##########################################################################
#
PS4='cogridded_extprdgen.merge $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
set -x

echo MDLLOG: `date` - Begin job exgfsmos_cogridded_extprdgen.merge

cd $DATA/cogridded/merge
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"
#######################################################################
#  COPY THE MDL FORECAST FILES FROM COM
#######################################################################
if test $cyc -eq '00'; then  # CIG/VIS for 00z Extended Only
    elemList="temp wind prcp skyc tstm cig vis"
else
    elemList="temp wind prcp skyc tstm"
    for cpElem in cig vis; do
        cpreq $COMIN/mdl_gfsgmosco.$cpElem.$cycle .
    done
fi

for cpElem in $elemList; do
    cpreq $DATA/cogridded/$cpElem/mdl_gfsgmosco.$cpElem.$cycle .
done

# Reset elemlist since we do want to include Cig and Vis in our combined file
elemList="temp wind prcp skyc tstm cig vis"
for coElem in $elemList; do


    ##############################################################################
    # PROGRAM ITDLP - CONVERTS THE RA ELEMENT ONLY FILES TO SEQ FOR CONCATONATION
    ##############################################################################
    export pgm=itdlp
    . prep_step
    export FORT10=$PDY$cyc
    export FORT30=mdl_gfsgmosco.$coElem.$cycle
    export FORT60=mdl_gfsxgmoscosq.$coElem.$cycle
    startmsg
    $EXECcode/$pgm $FORT30 -tdlp $FORT60
    export err=$?;err_chk

    cat mdl_gfsxgmoscosq.$coElem.$cycle >> mdl_gfsxgmoscosq.$cycle

    # Combine the station input files (non-tstm) and copy over the tsvr 40km file
    if [[ $coElem != "tstm" ]]; then
        cat $DATA/cogridded/$coElem/mdl_gfsxmergesta_co.$coElem.$cycle >> ./mdl_gfsxmergesta_co.$cycle
    else
        cpreq $DATA/cogridded/$coElem/mdl_gfsxtsvr40grd.sq.$cycle .
    fi

    # Combine the DMO and GOE files into the expected TDLpack files for com
    if [[ $coElem == "temp" || $coElem == "wind" || $coElem == "skyc" ]]; then
        cat $DATA/cogridded/$coElem/mdl_cogoedmoxgrsq.$coElem.$cycle >> ./mdl_cogoedmoxgrsq.$cycle
    elif [[ $coElem == "prcp" ]]; then
        cpreq $DATA/cogridded/$coElem/mdl_cogoemosxgrsq.$coElem.$cycle ./mdl_cogoemosxgrsq.$cycle
    fi

done

#######################################################################
# PROGRAM ITDLP - CONVERT CONCATONATED RECORD TO RA FOR EXTENDED RANGE
#######################################################################
export pgm=itdlp
. prep_step
export FORT10=$PDY$cyc
export FORT30=mdl_gfsxgmoscosq.$cycle
export FORT60=mdl_gfsgmosco.$cycle
startmsg
$EXECcode/$pgm $FORT30 -tdlpra $FORT60 -rasize large -date $DAT
export err=$?;err_chk


#######################################################################
# PROGRAM ITDLP - CLIPS THE GRIDS WITH A MASK BEFORE PACKING IN GRIB2
#######################################################################
export pgm=itdlp
. prep_step
export FORT10=$PDY$cyc
export FORT20=$FIXgfs_mos/mdl_co_mask.txt
export FORT30=mdl_gfsgmosco.$cycle
export FORT60=mdl_gfsgmosco_clip.$cycle
startmsg
$EXECcode/$pgm $FORT30 -clipgrid $FORT20 -tdlpra $FORT60
export err=$?;err_chk

#######################################################################
# PROGRAM RA2GRIB2 - CODES TDLPACK MOS FORECASTS INTO GRIB2. 
#######################################################################
#   WE'LL LOOP THROUGH THE FOLLOWING ELEMENTS, CREATING SEPARATE
#   GRIB2 FILES FOR EACH ELEMENT (PACKAGING NEEDED FOR TGFTP) 
#
#    TEMP = 2M SURFACE TEMPERATURE    DEWP = 2M SURFACE DEWPOINT
#    MAX  = MAXIMUM TEMPERATURE       MIN  = MINIMUM TEMPERATURE
#    RH   = 2M RELATIVE HUMIDITY      POP6 = 6HR POP
#   POP12 = 12HR POP                  WSPD = 10M WIND SPEED
#    WDIR = 10M WIND DIRECTION     PTSTM03 = 3HR THUNDERSTORM PROB (00Z ONLY)
# PTSTM06 = 6HR THUNDERSTORM PROB  PTSTM12 = 12HR THUNDERSTORM PROB
#   QPF06 = 6HR QPF                  QPF12 = 12HR QPF
#     SKY = OPAQUE SKY COVER         SNW24 = 24HR SNOWFALL
#    WGST = WIND GUST 
#
#######################################################################
for element in temp dewp max min rh ptstm06 ptstm12 wspd wdir wgst pop6 pop12 sky qpf06 qpf12 snw24 
do

echo MDLLOG: `date` - begin job RA2GRIB2 
export pgm=mdl_ra2grib2
. prep_step
startmsg
export FORT10="ncepdate"
export FORT31="$FIXgfs_mos/mdl_gmosgb2sect0-1"
export FORT32="$FIXgfs_mos/mdl_gmoscogb2sect3.2p5o"
export FORT33="$FIXgfs_mos/mdl_gmosxcogb2sect4${element}.$cycle"
export FORT34="$FIXgfs_mos/mdl_gmosxcogb2sect5${element}.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="mdl_gfsgmosco_clip.$cycle"
export FORT60="mdl_gmosxcogb2${element}.$cycle.nohead"
$EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_co.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RA2GRIB2 ended 

if [ "$SEND_OLD_GRID" == YES ]; then
   $WGRIB2 mdl_gmosxcogb2${element}.$cycle.nohead -ijsmall_grib 1:2145 1:1377 mdl_gmosxcogb2${element}.$cycle.nohead.1377.tmp -set_grib_type same
   export err=$?; err_chk
   $WGRIB2 -set_int 5 24 1176255488 mdl_gmosxcogb2${element}.$cycle.nohead.1377.tmp -grib mdl_gmosxcogb2${element}.$cycle.nohead.1377 -set_grib_type same
   export err=$?; err_chk
   send_label="nohead.1377"
else
   send_label="nohead"
fi

done

#######################################################################
#  3H TSTMS CIG AND VIS ONLY AVAILABLE AT 00Z IN EXTENDED CYCLE
#######################################################################

if test $cyc -eq '00'
then

for element in ptstm03 cig vis
do

echo MDLLOG: `date` - begin job RA2GRIB2
export pgm=mdl_ra2grib2
. prep_step
startmsg
export FORT10="ncepdate"
export FORT31="$FIXgfs_mos/mdl_gmosgb2sect0-1"
export FORT32="$FIXgfs_mos/mdl_gmoscogb2sect3.2p5o"
export FORT33="$FIXgfs_mos/mdl_gmosxcogb2sect4${element}.$cycle"
export FORT34="$FIXgfs_mos/mdl_gmosxcogb2sect5${element}.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="mdl_gfsgmosco_clip.$cycle"
export FORT60="mdl_gmosxcogb2${element}.$cycle.nohead"
$EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_co.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RA2GRIB2 ended

if [ "$SEND_OLD_GRID" == YES ]; then
   $WGRIB2 mdl_gmosxcogb2${element}.$cycle.nohead -ijsmall_grib 1:2145 1:1377 mdl_gmosxcogb2${element}.$cycle.nohead.1377.tmp -set_grib_type same
   export err=$?; err_chk
   $WGRIB2 -set_int 5 24 1176255488 mdl_gmosxcogb2${element}.$cycle.nohead.1377.tmp -grib mdl_gmosxcogb2${element}.$cycle.nohead.1377 -set_grib_type same
   export err=$?; err_chk
   send_label="nohead.1377"
else
   send_label="nohead"
fi

done

fi

#######################################################################
# NOTE: AT THIS POINT IN THE SCRIPT, WE HAVE CREATED GRIB2 FILES
#       WITH NO WMO HEADERS INSERTED. THESE ARE
#
#       mdl_gmosxcogb2${element}.$cycle.nohead
#
#  NOW RUN TOCGRIB2 TO PUT HEADERS AND FFS ON THE FILES
#  CAT ALL OF THE GRIB FILES TOGETHER AND RUN TOCGRIB2 ONCE
#######################################################################
touch mdl_gmosxcogrib2.$cycle

# NON POP/QPF ELEMENTS
for element in temp dewp max min rh wspd wdir ptstm06 ptstm12 sky snw24 wgst pop6 pop12 qpf06 qpf12
do
  cat mdl_gmosxcogb2${element}.$cycle.nohead >> mdl_gmosxcogrib2.$cycle
done

if test $cyc -eq '00'
then
  cat mdl_gmosxcogb2ptstm03.$cycle.nohead >> mdl_gmosxcogrib2.$cycle
fi

export pgm=grb2index
. prep_step
startmsg
$GRB2INDEX mdl_gmosxcogrib2.$cycle mdl_gmosxcogrib2i.$cycle
export err=$?; err_chk

export pgm=tocgrib2
. prep_step
startmsg
export FORT11="mdl_gmosxcogrib2.$cycle"
export FORT31="mdl_gmosxcogrib2i.$cycle"
export FORT51="mdl_gmosxcogrib2.xtrn.$cycle"
$TOCGRIB2 <$FIXgfs_mos/mdl_gmosxcogb2head.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

#######################################################################
# UTILITY TOCGRIB2SUPER - INSERTS WMO SUPERHEADERS AND INDIVIDUAL HEADERS
#                         INTO ELEMENT-SPECIFIC GRIB2 FILES, THEN CAT ALL
#                         ELEMENT-SPECIFIC GRIB2 FILES INTO ONE FILE.
#
# NOTE: FOR THE TRANSITION TO WCOSS, TOCGRIB2SUPER IS NOW BEING USED.
#######################################################################
for element in temp dewp max min rh pop6 pop12 wspd wdir ptstm06 ptstm12 qpf06 qpf12 sky snw24 wgst
do

echo 0 > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmosxcogb2${element}.$cycle.${send_label}"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmosxcogb2${element}.$cycle.temp"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmosxcogb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

echo `ls -l mdl_gmosxcogb2${element}.$cycle.temp | awk '{print $5}'` > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmosxcogb2${element}.$cycle.temp"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmosxcogb2${element}.xtrn.$cycle"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmosxcogb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

done

#######################################################################
#  3H TSTMS ONLY AVAILABLE AT 00Z IN EXTENDED CYCLE
#######################################################################
if test $cyc -eq '00'
then

for element in ptstm03
do

echo 0 > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmosxcogb2${element}.$cycle.${send_label}"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmosxcogb2${element}.$cycle.temp"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmosxcogb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

echo `ls -l mdl_gmosxcogb2${element}.$cycle.temp | awk '{print $5}'` > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmosxcogb2${element}.$cycle.temp"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmosxcogb2${element}.xtrn.$cycle"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmosxcogb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

done

fi
#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  # TDLPACK FILES
  cpfs mdl_gfsxmergesta_co.$cycle $COMOUT
  cpfs mdl_cogoedmoxgrsq.$cycle $COMOUT
  cpfs mdl_cogoemosxgrsq.$cycle $COMOUT
  cpfs mdl_gfsgmosco.$cycle $COMOUT
  cpfs mdl_gfsxtsvr40grd.sq.$cycle $COMOUT
  # ELEMENT-SPECIFIC GRIB2 FILES WITHOUT HEADERS. SENDING TO
  # COM WITHOUT THE .nohead EXTENSION.
  cpfs mdl_gmosxcogb2temp.$cycle.nohead $COMOUT/mdl_gmosxcogb2temp.$cycle
  cpfs mdl_gmosxcogb2dewp.$cycle.nohead $COMOUT/mdl_gmosxcogb2dewp.$cycle
  cpfs mdl_gmosxcogb2max.$cycle.nohead $COMOUT/mdl_gmosxcogb2max.$cycle
  cpfs mdl_gmosxcogb2min.$cycle.nohead $COMOUT/mdl_gmosxcogb2min.$cycle
  cpfs mdl_gmosxcogb2rh.$cycle.nohead $COMOUT/mdl_gmosxcogb2rh.$cycle
  cpfs mdl_gmosxcogb2ptstm06.$cycle.nohead $COMOUT/mdl_gmosxcogb2ptstm06.$cycle
  cpfs mdl_gmosxcogb2ptstm12.$cycle.nohead $COMOUT/mdl_gmosxcogb2ptstm12.$cycle
  cpfs mdl_gmosxcogb2wspd.$cycle.nohead $COMOUT/mdl_gmosxcogb2wspd.$cycle
  cpfs mdl_gmosxcogb2wdir.$cycle.nohead $COMOUT/mdl_gmosxcogb2wdir.$cycle
  cpfs mdl_gmosxcogb2wgst.$cycle.nohead $COMOUT/mdl_gmosxcogb2wgst.$cycle
  cpfs mdl_gmosxcogb2pop6.$cycle.nohead $COMOUT/mdl_gmosxcogb2pop6.$cycle
  cpfs mdl_gmosxcogb2pop12.$cycle.nohead $COMOUT/mdl_gmosxcogb2pop12.$cycle
  cpfs mdl_gmosxcogb2sky.$cycle.nohead $COMOUT/mdl_gmosxcogb2sky.$cycle
  cpfs mdl_gmosxcogb2qpf06.$cycle.nohead $COMOUT/mdl_gmosxcogb2qpf06.$cycle
  cpfs mdl_gmosxcogb2qpf12.$cycle.nohead $COMOUT/mdl_gmosxcogb2qpf12.$cycle
  cpfs mdl_gmosxcogb2snw24.$cycle.nohead $COMOUT/mdl_gmosxcogb2snw24.$cycle
  # SEND PTSTM03 ONLY IF 00Z. WE ARE NOT SENDING THE 00Z PTSTM03 FILE
  # TO COMOUTwmo SINCE IT IS NOT BEING ALTERTED TO TGFTP.
  if test $cyc -eq '00'
  then
    cpfs mdl_gmosxcogb2ptstm03.$cycle.nohead $COMOUT/mdl_gmosxcogb2ptstm03.$cycle
    cpfs mdl_gmosxcogb2cig.$cycle.nohead $COMOUT/mdl_gmosxcogb2cig.$cycle
    cpfs mdl_gmosxcogb2vis.$cycle.nohead $COMOUT/mdl_gmosxcogb2vis.$cycle
  fi

fi

##########################################################################################
##########################################################################################
# THE FOLLOWING ARE FOR PUTTING EXTRA-EXTENDED RANGE GMOS INTO GRIB2.
##########################################################################################
##########################################################################################

#######################################################################
# PROGRAM RA2GRIB2 - CODES TDLPACK MOS FORECASTS INTO GRIB2.
#######################################################################
#   WE'LL LOOP THROUGH THE FOLLOWING ELEMENTS, CREATING SEPARATE
#   GRIB2 FILES FOR EACH ELEMENT (PACKAGING NEEDED FOR TGFTP)
#
#    TEMP = 2M SURFACE TEMPERATURE    DEWP = 2M SURFACE DEWPOINT
#    MAX  = MAXIMUM TEMPERATURE       MIN  = MINIMUM TEMPERATURE
#    RH   = 2M RELATIVE HUMIDITY     POP12 = 12HR POP
#    WSPD = 10M WIND SPEED            WDIR = 10M WIND DIRECTION
#
#######################################################################
for element in temp dewp max min rh pop12 wspd wdir
do

   echo MDLLOG: `date` - begin job RA2GRIB2
   export pgm=mdl_ra2grib2
   . prep_step
   export FORT10="ncepdate"
   export FORT31="$FIXgfs_mos/mdl_gmosxxcogb2sect0-1"
   export FORT32="$FIXgfs_mos/mdl_gmosxxcogb2sect3.2p5o"
   export FORT33="$FIXgfs_mos/mdl_gmosxxcogb2sect4${element}.$cycle"
   export FORT34="$FIXgfs_mos/mdl_gmosxxcogb2sect5${element}.$cycle"
   export FORT29="$FIXcode/mdl_mos2000id.tbl"
   export FORT44="mdl_gfsgmosco_clip.$cycle"
   export FORT60="mdl_gmosxxcogb2${element}.$cycle.nohead"
   startmsg
   $EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_co.cn >> $pgmout 2>errfile
   export err=$?; err_chk
   echo MDLLOG: `date` -  RA2GRIB2 ended

done

#######################################################################
# NOTE: AT THIS POINT IN THE SCRIPT, WE HAVE CREATED GRIB2 FILES
#       WITH NO WMO HEADERS INSERTED. THESE ARE
#
#       mdl_gmosxxcogb2${element}.$cycle.nohead
#
#  NOW RUN TOCGRIB2 TO PUT HEADERS AND FFS ON THE FILES
#  CAT ALL OF THE GRIB FILES TOGETHER AND RUN TOCGRIB2 ONCE
#######################################################################
touch mdl_gmosxxcogrib2.$cycle

for element in temp dewp max min rh pop12 wspd wdir
do
  cat mdl_gmosxxcogb2${element}.$cycle.nohead >> mdl_gmosxxcogrib2.$cycle
done

export pgm=grb2index
. prep_step
startmsg
$GRB2INDEX mdl_gmosxxcogrib2.$cycle mdl_gmosxxcogrib2i.$cycle
export err=$?; err_chk

export pgm=tocgrib2
. prep_step
startmsg
export FORT11="mdl_gmosxxcogrib2.$cycle"
export FORT31="mdl_gmosxxcogrib2i.$cycle"
export FORT51="mdl_gmosxxcogrib2.xtrn.$cycle"
$TOCGRIB2 <$FIXgfs_mos/mdl_gmosxxcogb2head.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

#######################################################################
# UTILITY TOCGRIB2SUPER - INSERTS WMO SUPERHEADERS AND INDIVIDUAL HEADERS
#                         INTO ELEMENT-SPECIFIC GRIB2 FILES, THEN CAT ALL
#                         ELEMENT-SPECIFIC GRIB2 FILES INTO ONE FILE.
#######################################################################
for element in temp dewp max min rh pop12 wspd wdir
do

echo 0 > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmosxxcogb2${element}.$cycle.nohead"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmosxxcogb2${element}.$cycle.temp"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmosxxcogb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

echo `ls -l mdl_gmosxxcogb2${element}.$cycle.temp | awk '{print $5}'` > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmosxxcogb2${element}.$cycle.temp"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmosxxcogb2${element}.xtrn.$cycle"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmosxxcogb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

done

#######################################################################
# COPY "XX" FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  # ELEMENT-SPECIFIC GRIB2 FILES WITHOUT HEADERS. SENDING TO
  # COM WITHOUT THE .nohead EXTENSION.
  cpfs mdl_gmosxxcogb2temp.$cycle.nohead $COMOUT/mdl_gmosxxcogb2temp.$cycle
  cpfs mdl_gmosxxcogb2dewp.$cycle.nohead $COMOUT/mdl_gmosxxcogb2dewp.$cycle
  cpfs mdl_gmosxxcogb2max.$cycle.nohead $COMOUT/mdl_gmosxxcogb2max.$cycle
  cpfs mdl_gmosxxcogb2min.$cycle.nohead $COMOUT/mdl_gmosxxcogb2min.$cycle
  cpfs mdl_gmosxxcogb2rh.$cycle.nohead $COMOUT/mdl_gmosxxcogb2rh.$cycle
  cpfs mdl_gmosxxcogb2pop12.$cycle.nohead $COMOUT/mdl_gmosxxcogb2pop12.$cycle
  cpfs mdl_gmosxxcogb2wspd.$cycle.nohead $COMOUT/mdl_gmosxxcogb2wspd.$cycle
  cpfs mdl_gmosxxcogb2wdir.$cycle.nohead $COMOUT/mdl_gmosxxcogb2wdir.$cycle
fi

##########################################################################################
##########################################################################################
# END OF CREATING AND ALERTING EXTRA-EXTENDED "XX" RANGE PRODUCTS.
##########################################################################################
##########################################################################################

#######################################################################
#
# PROGRAM GRIDARCH - ARCHIVES THE GRIDDED
#                    FORECASTS FOR ALL PROJECTIONS (6 - 198).
#######################################################################

echo MDLLOG: `date` - begin job GRIDARCH - ARCHIVES GRIDDED MOS FORECASTS
export pgm=mdl_gridarch
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_granlsta_co.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_co.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsgrarch_co.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT43="mdl_gfsgmosco.$cycle"
export FORT60="mdl_gfsgmoscosq.$cycle"
$EXECcode/mdl_gridarch < $PARMgfs_mos/mdl_gridarch_co.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDARCH ended

if test $SENDCOM = 'YES'
then
  cpfs mdl_gfsgmoscosq.$cycle $COMOUT
fi

#######################################################################
echo MDLLOG: `date` - Job gfsmos_cogridded_extprdgen.merge has ended.
#######################################################################
