#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_akgridded_prdgen.merge.sh.ecf 
#  Purpose: To run all steps necessary to create short range GFS-based
#           gridded MOS fcsts on the AK NDFD grid
#  Remarks: This script is kicked off when the 4 forecast jobs
#           METAR, AKGOE, COOPMESO, and TSTM have completed. 
#           The goe and gridded forecasts are archived in the 
#           extended-range job.
#
#  HISTORY: Mar 03, 2008  RLC    - new job for AK Gridded MOS.  Right 
#                                  now we're just putting in thunderstorms.
#           Mar 26, 2008  RLC    - adding temperatures before we 
#                                  implement for the first time.
#                               Note:  the sleep command is included to
#                               delay dissemination time.  As more fields
#                               are added the sleep time will decrease to
#                               minimize the impact on the future
#                               dissemination times. 
#           Sep 26, 2008  RLC    - adding winds, POPs, and sky. POP and 
#                                  sky have goe-based first guesses, 
#                                  wind uses dmo. To be implemented
#                                  12/2008
#           Dec 11, 2009  GAW    - adding QPF and snow.  To be
#                                  implemented 1/2010, but snow and
#                                  qpf grids will not be sent to the
#                                  SBN yet.
#           Feb 18, 2010  EFE    - adding QPF and snow to TOCGRIB2 file
#                                  for transmission over SBN. To be
#                                  implemented 3/30/2010.
#           Dec 03, 2012  EFE    - Transitioned to WCOSS (Linux). Changed
#                                  all 'XLFUNIT_  ' env vars to 'FORT  '
#           Feb 05, 2016  SDS    - Configured for MPMD
#           Mar 2018      GAW - Split from exgfsmos_akgridded_prdgen.sh.ecf
#                               for parallel runs of GMOS element groups
#           Nov 2018      JLW    - Added CIG and VIS
#           Jul 26, 2019  SDS    - Removed dissemination of grids
#
#######################################################################
#
set -x
PS4='akgridded_prdgen.merge $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_akgridded_prdgen.merge

cd $DATA/akgridded/merge
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
#  COPY THE MDL FORECAST FILES FROM COM
#######################################################################
for akElem in temp wind prcp skyc tstm cig vis; do

    cpreq $DATA/akgridded/$akElem/mdl_gfsgmosak.$akElem.$cycle .

    ##############################################################################
    # PROGRAM ITDLP - CONVERTS THE RA ELEMENT ONLY FILES TO SEQ FOR CONCATONATION
    ##############################################################################
    export pgm=itdlp
    . prep_step
    export FORT10=$PDY$cyc
    export FORT30=mdl_gfsgmosak.$akElem.$cycle
    export FORT60=mdl_gfsgmosaksq.$akElem.$cycle
    startmsg
    $EXECcode/$pgm $FORT30 -tdlp $FORT60
    export err=$?;err_chk

    cat mdl_gfsgmosaksq.$akElem.$cycle >> mdl_gfsgmosaksq.$cycle

    # Combine the station input files (non-tstm) and copy over the tsvr 40km file
    if [[ $akElem != "tstm" ]]; then
        cat $DATA/akgridded/$akElem/mdl_gfsmergesta_ak.$akElem.$cycle >> ./mdl_gfsmergesta_ak.$cycle
    else
        cpreq $DATA/akgridded/$akElem/mdl_gfstsvrak47grd.sq.$cycle .
    fi

    # Combine the DMO and GOE files into the expected TDLpack files for com
    if [[ $akElem == "temp" || $akElem == "wind" ]]; then
        cat $DATA/akgridded/$akElem/mdl_akdmogrsq.$akElem.$cycle >> ./mdl_akdmogrsq.$cycle
    elif [[ $akElem == "prcp" || $akElem == "skyc" ]]; then
        cat $DATA/akgridded/$akElem/mdl_akgoegrsq.$akElem.$cycle >> ./mdl_akgoegrsq.$cycle
    fi

done

######################################################################
# PROGRAM ITDLP - CONVERT CONCATONATED RECORD TO RA FOR EXTENDED RANGE
#######################################################################
export pgm=itdlp
. prep_step
export FORT10=$PDY$cyc
export FORT30=mdl_gfsgmosaksq.$cycle
export FORT60=mdl_gfsgmosak.$cycle
startmsg
$EXECcode/$pgm $FORT30 -tdlpra $FORT60 -rasize large -date $DAT
export err=$?;err_chk

#######################################################################
# PROGRAM ITDLP - CLIPS THE GRIDS WITH A MASK BEFORE PACKING IN GRIB2
#######################################################################
export pgm=itdlp
. prep_step
export FORT10=$PDY$cyc
export FORT20=$FIXgfs_mos/mdl_ak_mask.txt
export FORT30=mdl_gfsgmosak.$cycle
export FORT60=mdl_gfsgmosak_clip.$cycle
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
#    WDIR = 10M WIND DIRECTION     PTSTM03 = 3HR THUNDERSTORM PROB
# PTSTM06 = 6HR THUNDERSTORM PROB  PTSTM12 = 12HR THUNDERSTORM PROB
#   QPF06 = 6HR QPF                  QPF12 = 12HR QPF
#     SKY = OPAQUE SKY COVER         SNW24 = 24HR SNOWFALL
#    WGST = WIND GUST
#
#######################################################################
for element in temp dewp max min rh ptstm03 ptstm06 ptstm12 wspd wdir wgst pop12 pop6 sky qpf06 qpf12 snw24 cig vis
do

echo MDLLOG: `date` - begin job RA2GRIB2 
export pgm=mdl_ra2grib2
. prep_step
export FORT10="ncepdate"
export FORT31="$FIXgfs_mos/mdl_gmosgb2sect0-1"
export FORT32="$FIXgfs_mos/mdl_gmosakgb2sect3"
export FORT33="$FIXgfs_mos/mdl_gmosakgb2sect4${element}.$cycle"
export FORT34="$FIXgfs_mos/mdl_gmosakgb2sect5${element}.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="mdl_gfsgmosak_clip.$cycle"
export FORT60="mdl_gmosakgb2${element}.$cycle"
startmsg
$EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_ak.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RA2GRIB2 ended 

done

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_gfsmergesta_ak.$cycle $COMOUT
  cpfs mdl_akdmogrsq.$cycle $COMOUT
  cpfs mdl_akgoegrsq.$cycle $COMOUT
  cpfs mdl_gfsgmosak.$cycle $COMOUT
  cpfs mdl_gfsgmosak.temp.$cycle $COMOUT
  cpfs mdl_gfsgmosak.wind.$cycle $COMOUT
  cpfs mdl_gfsgmosak.prcp.$cycle $COMOUT
  cpfs mdl_gfsgmosak.skyc.$cycle $COMOUT
  cpfs mdl_gfsgmosak.tstm.$cycle $COMOUT
  #Commenting out these two because these records will exist on the RA file, on the NDFD grid
  #cp mdl_gfsgmosaksq_pp.$cycle $COMOUT
  #cp mdl_gfsgmosakndfdgrid.$cycle $COMOUT
  cpfs mdl_gfstsvrak47grd.sq.$cycle $COMOUT
  cpfs mdl_gmosakgb2temp.$cycle $COMOUT
  cpfs mdl_gmosakgb2dewp.$cycle $COMOUT
  cpfs mdl_gmosakgb2max.$cycle $COMOUT
  cpfs mdl_gmosakgb2min.$cycle $COMOUT
  cpfs mdl_gmosakgb2rh.$cycle $COMOUT
  cpfs mdl_gmosakgb2ptstm03.$cycle $COMOUT
  cpfs mdl_gmosakgb2ptstm06.$cycle $COMOUT
  cpfs mdl_gmosakgb2ptstm12.$cycle $COMOUT
  cpfs mdl_gmosakgb2wspd.$cycle $COMOUT
  cpfs mdl_gmosakgb2wdir.$cycle $COMOUT
  cpfs mdl_gmosakgb2wgst.$cycle $COMOUT
  cpfs mdl_gmosakgb2pop6.$cycle $COMOUT
  cpfs mdl_gmosakgb2pop12.$cycle $COMOUT
  cpfs mdl_gmosakgb2sky.$cycle $COMOUT
  cpfs mdl_gmosakgb2qpf06.$cycle $COMOUT
  cpfs mdl_gmosakgb2qpf12.$cycle $COMOUT
  cpfs mdl_gmosakgb2snw24.$cycle $COMOUT
  cpfs mdl_gmosakgb2cig.$cycle $COMOUT
  cpfs mdl_gmosakgb2vis.$cycle $COMOUT

fi

#######################################################################
#  NOW RUN TOCGRIB2 TO PUT HEADERS AND FFS ON THE FILES
#   CAT ALL OF THE GRIB FILES TOGETHER AND RUN TOCGRIB2 ONCE
#######################################################################
  touch mdl_gmosakgrib2.$cycle

  for element in temp dewp max min rh ptstm03 ptstm06 ptstm12 wspd wdir wgst pop6 pop12 sky qpf06 qpf12 snw24
   do
    cat mdl_gmosakgb2${element}.$cycle >> mdl_gmosakgrib2.$cycle
   done

  $GRB2INDEX mdl_gmosakgrib2.$cycle mdl_gmosakgrib2i.$cycle

export FORT11="mdl_gmosakgrib2.$cycle"
export FORT31="mdl_gmosakgrib2i.$cycle"
export FORT51="mdl_gmosakgrib2.xtrn.$cycle"

$TOCGRIB2 <$PARMgfs_mos/mdl_gmosakgb2head.$cycle 1>> $pgmout 2>> errfile

if test $SENDCOM = 'YES'
then
  cpfs mdl_gmosakgrib2.xtrn.$cycle $COMOUT
fi

#######################################################################
echo MDLLOG: `date` - Job exgfsmos_akgridded_prdgen has ended.
#######################################################################
