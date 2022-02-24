#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_cogridded_prdgen.merge.sh.ecf 
#  Purpose: To run all steps necessary to create short range GFS-based
#           gridded MOS fcsts on the CONUS 2.5 km NDFD Grid.
#  Remarks: This script is kicked off when the 4 forecast jobs
#           METAR, GOE, COOPMESO, and TSTM have completed. 
#           The goe and gridded forecasts are archived in the 
#           extended-range job.
#
#           For the time being, 2.5 km CONUS GMOS will use the 5 km
#           GOE files created exgfsmos_goe_fcst.sh.ecf.
#
#  HISTORY: Jan 05, 2011  EFE    - New job for CONUS 2.5 km Gridded 
#                                  MOS. Adapted from Alaska Gridded
#                                  prdgen scripts because CONUS 2.5 km
#                                  GMOS is now using U155 version 9.
#           Feb 08, 2011  EFE    - Updated section of the script that
#                                  creates GRIB2 files. Because of
#                                  current TOC limitations with file
#                                  transmission sizes, we will be 
#                                  creating 3 sets of data that will be
#                                  described below. More information
#                                  is contained in that part of the
#                                  script.
#           Mar 31, 2011  EFE    - Added section after GRIDPOST to check
#                                  for HRQPF GRIB2 files. If available,
#                                  these files will be used as official
#                                  products and alerted; if not, the
#                                  regular GMOS POP/QPF files will be
#                                  used.
#           Nov 08, 2012  EFE    - Added dbn_alert commands for superheaded
#                                  element GRIB2 files in $PCOM
#           Nov 19, 2012  EFE    - Turn off dbn alerts for non-headed 2.5KM
#                                  CONUS GMOS GRIB2 files, using subtype string
#                                  "GMOSCO*"; Added "hr" to copy destination name
#                                  of HR POP/QPF superheaded GRIB2 files to /PCOM.
#           Dec 03, 2012  EFE    - Transitioned to WCOSS (Linux). Changed
#                                  all 'FORT  ' env vars to 'FORT  '. Change all
#                                  uses of aqm_smoke to tocgrib2super.
#           Sep 17, 2013  EFE    - Uncommented dbn_alert commands for individual
#                                  element GRIB2 files without WMO headers. These lines
#                                  were uncommented by NCO on 4/22/2012 and this is
#                                  update our version. Also, POP and QPF lines remain
#                                  commented to stay consistent with what is in nwprod.
#           Oct  5, 2015  SDS    - Clip disseminated GRIB2 data to be on the old grid
#                                  after new grid broke in AWIPS2. Use SEND_OLD_GRID
#                                  variable to trigger whether you want to clip.
#           Oct  7, 2015  GAW    - Bug fix to regain any original Mesowest sites present
#                                  in the new MADIS mesonet MOS forecasts.  Uses utility
#                                  codes repackmeso and itdlp adjust station call letters
#                                  prior to RAMERGE.
#           Oct 22, 2015  GAW    - Tweak to pull the partial RA file for Coop/Mesonet MOS
#                                  from /com and flip it using itdlp to seq (for repackmeso).
#           Feb  5, 2016  SDS    - Configured for MPMD
#           Mar 10, 2016  SDS    - Removed HRQPF dependency
#           Mar 2018      GAW - Split from exgfsmos_cogridded_prdgen.sh.ecf
#                               for parallel runs of GMOS element groups
#           Nov 2018      JLW    - Added CIG and VIS
#           Jul 26, 2019  SDS    - Removed dissemination of grids.    
#
#           NOTE: On approx. 12/13/12, NCO will begin routing 2.5KM CONUS GMOS
#                 GRIB2 files to TOC with superheaders and inidividual headers.
#                 Superheaders will be sents to TGFTP and inidividual headers
#                 will be sent to SBN/NOAAPORT.
#######################################################################
#
PS4='cogridded_prdgen.merge $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
set -x
echo MDLLOG: `date` - Begin job exgfsmos_cogridded_prdgen

cd $DATA/cogridded/merge
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"
#######################################################################
#  COPY THE MDL FORECAST FILES FROM COM
#######################################################################
for coElem in temp wind prcp skyc tstm cig vis; do

    cpreq $DATA/cogridded/$coElem/mdl_gfsgmosco.$coElem.$cycle .

    ##############################################################################
    # PROGRAM ITDLP - CONVERTS THE RA ELEMENT ONLY FILES TO SEQ FOR CONCATONATION
    ##############################################################################
    export pgm=itdlp
    . prep_step
    export FORT10=$PDY$cyc
    export FORT30=mdl_gfsgmosco.$coElem.$cycle
    export FORT60=mdl_gfsgmoscosq.$coElem.$cycle
    startmsg
    $EXECcode/$pgm $FORT30 -tdlp $FORT60
    export err=$?;err_chk

    cat mdl_gfsgmoscosq.$coElem.$cycle >> mdl_gfsgmoscosq.$cycle

    # Combine the station input files (non-tstm) and copy over the tsvr 40km file
    if [[ $coElem != "tstm" ]]; then
        cat $DATA/cogridded/$coElem/mdl_gfsmergesta_co.$coElem.$cycle >> ./mdl_gfsmergesta_co.$cycle
    else
        cpreq $DATA/cogridded/$coElem/mdl_gfstsvr40grd.sq.$cycle .
    fi

    # Combine the DMO and GOE files into the expected TDLpack files for com
    if [[ $coElem == "temp" || $coElem == "wind" || $coElem == "skyc" ]]; then
        cat $DATA/cogridded/$coElem/mdl_cogoedmogrsq.$coElem.$cycle >> ./mdl_cogoedmogrsq.$cycle
    elif [[ $coElem == "prcp" ]]; then
        cpreq $DATA/cogridded/$coElem/mdl_cogoemosgrsq.$coElem.$cycle ./mdl_cogoemosgrsq.$cycle
    fi

done

#######################################################################
# PROGRAM ITDLP - CONVERT CONCATONATED RECORD TO RA FOR EXTENDED RANGE
#######################################################################
export pgm=itdlp
. prep_step
export FORT10=$PDY$cyc
export FORT30=mdl_gfsgmoscosq.$cycle
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
$EXECcode/$pgm $FORT30 -clipgrid $FORT20 -tdlpra $FORT60 -rasize large
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
#    WDIR = 10M WIND DIRECTION     PTSTM03 = 3HR THUNDERSTORM PROB
# PTSTM06 = 6HR THUNDERSTORM PROB  PTSTM12 = 12HR THUNDERSTORM PROB
#   QPF06 = 6HR QPF                  QPF12 = 12HR QPF
#     SKY = OPAQUE SKY COVER         SNW24 = 24HR SNOWFALL
#    WGST = WIND GUST
#
#######################################################################
for element in temp dewp max min rh pop6 pop12 wspd wdir ptstm03 ptstm06 ptstm12 qpf06 qpf12 sky snw24 wgst cig vis
do

echo MDLLOG: `date` - begin job RA2GRIB2 
export pgm=mdl_ra2grib2
. prep_step
startmsg
export FORT10="ncepdate"
export FORT31="$FIXgfs_mos/mdl_gmosgb2sect0-1"
export FORT32="$FIXgfs_mos/mdl_gmoscogb2sect3.2p5o"
export FORT33="$FIXgfs_mos/mdl_gmoscogb2sect4${element}.$cycle"
export FORT34="$FIXgfs_mos/mdl_gmoscogb2sect5${element}.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="mdl_gfsgmosco_clip.$cycle"
export FORT60="mdl_gmoscogb2${element}.$cycle.nohead"
$EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_co.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RA2GRIB2 ended 

if [ "$SEND_OLD_GRID" == YES ]; then
   $WGRIB2 mdl_gmoscogb2${element}.$cycle.nohead -ijsmall_grib 1:2145 1:1377 mdl_gmoscogb2${element}.$cycle.nohead.1377.tmp -set_grib_type same
   export err=$?; err_chk
   $WGRIB2 -set_int 5 24 1176255488 mdl_gmoscogb2${element}.$cycle.nohead.1377.tmp -grib mdl_gmoscogb2${element}.$cycle.nohead.1377 -set_grib_type same
   export err=$?; err_chk
   send_label="nohead.1377"
else
   send_label="nohead"
fi

done

#######################################################################
# NOTE: AT THIS POINT IN THE SCRIPT, WE HAVE CREATED GRIB2 FILES
#       WITH NO WMO HEADERS INSERTED. THESE ARE 
#
#       mdl_gmoscogb2${element}.$cycle.nohead
#
#  NOW RUN TOCGRIB2 TO PUT HEADERS AND FFS ON THE FILES
#  CAT ALL OF THE GRIB FILES TOGETHER AND RUN TOCGRIB2 ONCE
#
# NOTE (4/1/2011): THIS SECTION NOW CONTAINS 2 FOR LOOPS. THE FIRST
# LOOP WILL CAT ALL ELEMENT EXCEPT FOR POP/QPF ELEMENTS. THE SECOND
# FOR LOOP WILL CAT EITHER THE "REGULAR" GMOS POP/QPF FILES OR THE
# HI-RES POP/QPF FILES BASED ON IF THE HI-RES POP/QPF FILE ARE
# AVAILABLE.
#######################################################################
touch mdl_gmoscogrib2.$cycle

# NON POP/QPF ELEMENTS
for element in temp dewp max min rh wspd wdir ptstm03 ptstm06 ptstm12 sky snw24 wgst pop6 pop12 qpf06 qpf12
do
  cat mdl_gmoscogb2${element}.$cycle.nohead >> mdl_gmoscogrib2.$cycle
done

export pgm=grb2index
. prep_step
startmsg
$GRB2INDEX mdl_gmoscogrib2.$cycle mdl_gmoscogrib2i.$cycle
export err=$?; err_chk

export pgm=tocgrib2
. prep_step
startmsg
export FORT11="mdl_gmoscogrib2.$cycle"
export FORT31="mdl_gmoscogrib2i.$cycle"
export FORT51="mdl_gmoscogrib2.xtrn.$cycle"
$TOCGRIB2 <$FIXgfs_mos/mdl_gmoscogb2head.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

#######################################################################
# UTILITY TOCGRIB2SUPER - INSERTS WMO SUPERHEADERS AND INDIVIDUAL HEADERS
#                         INTO ELEMENT-SPECIFIC GRIB2 FILES, THEN CAT ALL
#                         ELEMENT-SPECIFIC GRIB2 FILES INTO ONE FILE.
#
# NOTE: FOR THE TRANSITION TO WCOSS, TOCGRIB2SUPER IS NOW BEING USED. 
#######################################################################
for element in temp dewp max min rh pop6 pop12 wspd wdir ptstm03 ptstm06 ptstm12 qpf06 qpf12 sky snw24 wgst
do

echo 0 > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmoscogb2${element}.$cycle.${send_label}"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmoscogb2${element}.$cycle.temp"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmoscogb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

echo `ls -l mdl_gmoscogb2${element}.$cycle.temp | awk '{print $5}'` > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmoscogb2${element}.$cycle.temp"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmoscogb2${element}.xtrn.$cycle"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmoscogb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

done
#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  # TDLPACK FILES
  cpfs mdl_gfsmergesta_co.$cycle $COMOUT
  cpfs mdl_cogoedmogrsq.$cycle $COMOUT
  cpfs mdl_cogoemosgrsq.$cycle $COMOUT
  #Element-specific RA files copied to com here to extended-range considerations
  #All-element RA still needed for Wx Grid Input
  cpfs mdl_gfsgmosco.$cycle $COMOUT
  cpfs mdl_gfsgmosco.temp.$cycle $COMOUT
  cpfs mdl_gfsgmosco.wind.$cycle $COMOUT
  cpfs mdl_gfsgmosco.prcp.$cycle $COMOUT
  cpfs mdl_gfsgmosco.skyc.$cycle $COMOUT
  cpfs mdl_gfsgmosco.tstm.$cycle $COMOUT
  cpfs mdl_gfstsvr40grd.sq.$cycle $COMOUT
  # ELEMENT-SPECIFIC GRIB2 FILES WITHOUT HEADERS. SENDING TO
  # COM WITHOUT THE .nohead EXTENSION.
  #
  # THERE IS NO NEED TO COPY THE HI-RES POP/QPF FILES BACK INTO
  # COM.
  cpfs mdl_gmoscogb2temp.$cycle.nohead $COMOUT/mdl_gmoscogb2temp.$cycle
  cpfs mdl_gmoscogb2dewp.$cycle.nohead $COMOUT/mdl_gmoscogb2dewp.$cycle
  cpfs mdl_gmoscogb2max.$cycle.nohead $COMOUT/mdl_gmoscogb2max.$cycle
  cpfs mdl_gmoscogb2min.$cycle.nohead $COMOUT/mdl_gmoscogb2min.$cycle
  cpfs mdl_gmoscogb2rh.$cycle.nohead $COMOUT/mdl_gmoscogb2rh.$cycle
  cpfs mdl_gmoscogb2ptstm03.$cycle.nohead $COMOUT/mdl_gmoscogb2ptstm03.$cycle
  cpfs mdl_gmoscogb2ptstm06.$cycle.nohead $COMOUT/mdl_gmoscogb2ptstm06.$cycle
  cpfs mdl_gmoscogb2ptstm12.$cycle.nohead $COMOUT/mdl_gmoscogb2ptstm12.$cycle
  cpfs mdl_gmoscogb2wspd.$cycle.nohead $COMOUT/mdl_gmoscogb2wspd.$cycle
  cpfs mdl_gmoscogb2wdir.$cycle.nohead $COMOUT/mdl_gmoscogb2wdir.$cycle
  cpfs mdl_gmoscogb2wgst.$cycle.nohead $COMOUT/mdl_gmoscogb2wgst.$cycle
  cpfs mdl_gmoscogb2pop6.$cycle.nohead $COMOUT/mdl_gmoscogb2pop6.$cycle
  cpfs mdl_gmoscogb2pop12.$cycle.nohead $COMOUT/mdl_gmoscogb2pop12.$cycle
  cpfs mdl_gmoscogb2sky.$cycle.nohead $COMOUT/mdl_gmoscogb2sky.$cycle
  cpfs mdl_gmoscogb2qpf06.$cycle.nohead $COMOUT/mdl_gmoscogb2qpf06.$cycle
  cpfs mdl_gmoscogb2qpf12.$cycle.nohead $COMOUT/mdl_gmoscogb2qpf12.$cycle
  cpfs mdl_gmoscogb2snw24.$cycle.nohead $COMOUT/mdl_gmoscogb2snw24.$cycle
  cpfs mdl_gmoscogb2cig.$cycle.nohead $COMOUT/mdl_gmoscogb2cig.$cycle
  cpfs mdl_gmoscogb2vis.$cycle.nohead $COMOUT/mdl_gmoscogb2vis.$cycle
fi

#######################################################################
echo MDLLOG: `date` - Job exgfsmos_cogridded_prdgen has ended.
#######################################################################
