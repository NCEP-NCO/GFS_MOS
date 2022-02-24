#!/bin/sh
##########################################################################
#  Job Name: exgfsmos_akgridded_extprdgen.merge.sh.ecf 
#  Purpose: To run all steps necessary to create extended-range GFS-based
#           gridded MOS fcsts for Alaska on the 3-km NDFD grid
#  Remarks: This script is kicked off when the forecast jobs
#           METAR, AK GOE, COOPMESO, and TSTM have completed
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
#           Dec 03, 2012  EFE - Transitioned to WCOSS (Linux). Changed
#                               all 'XLFUNIT_  ' env vars to 'FORT  '
#           Feb 10, 2016  SDS - Configured for MPMD
#           Mar 2018      GAW - Split from exgfsmos_akgridded_extprdgen.sh.ecf
#                               for parallel runs of GMOS element groups
#           Nov 2018      JLW - Added CIG and VIS
#           Jul 26, 2019  SDS - Removed dissemination of grids
#
##########################################################################
#
PS4='akgridded_extprdgen.merge $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_akgridded_extprdgen.merge

set -x

cd $DATA/akgridded/merge
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
        cpreq $COMIN/mdl_gfsgmosak.$cpElem.$cycle .
    done
fi

for cpElem in $elemList; do
    cpreq $DATA/akgridded/$cpElem/mdl_gfsgmosak.$cpElem.$cycle .
done

# Reset elemlist since we do want to include Cig and Vis in our combined file
elemList="temp wind prcp skyc tstm cig vis"

for akElem in $elemList; do

    ##############################################################################
    # PROGRAM ITDLP - CONVERTS THE RA ELEMENT ONLY FILES TO SEQ FOR CONCATONATION
    ##############################################################################
    export pgm=itdlp
    . prep_step
    export FORT10=$PDY$cyc
    export FORT30=mdl_gfsgmosak.$akElem.$cycle
    export FORT60=mdl_gfsxgmosaksq.$akElem.$cycle
    startmsg
    $EXECcode/$pgm $FORT30 -tdlp $FORT60
    export err=$?;err_chk

    cat mdl_gfsxgmosaksq.$akElem.$cycle >> mdl_gfsxgmosaksq.cat.$cycle

    # Combine the station input files (non-tstm) and copy over the tsvr 40km file
    if [[ $akElem != "tstm" ]]; then
        cat $DATA/akgridded/$akElem/mdl_gfsxmergesta_ak.$akElem.$cycle >> ./mdl_gfsxmergesta_ak.$cycle
    else
        cpreq $DATA/akgridded/$akElem/mdl_gfsxtsvrak47grd.sq.$cycle .
    fi

    # Combine the DMO and GOE files into the expected TDLpack files for com
    if [[ $akElem == "temp" || $akElem == "wind" ]]; then
        cat $DATA/akgridded/$akElem/mdl_akxdmogrsq.$akElem.$cycle >> ./mdl_akxdmogrsq.$cycle
    elif [[ $akElem == "prcp" || $akElem == "skyc" ]]; then
        cat $DATA/akgridded/$akElem/mdl_akxgoegrsq.$akElem.$cycle >> ./mdl_akxgoegrsq.$cycle
    fi

done

######################################################################
# PROGRAM ITDLP - CONVERT CONCATONATED RECORD TO RA FOR EXTENDED RANGE
#######################################################################
export pgm=itdlp
. prep_step
export FORT10=$PDY$cyc
export FORT30=mdl_gfsxgmosaksq.cat.$cycle
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
export FORT10="ncepdate"
export FORT31="$FIXgfs_mos/mdl_gmosgb2sect0-1"
export FORT32="$FIXgfs_mos/mdl_gmosakgb2sect3"
export FORT33="$FIXgfs_mos/mdl_gmosxakgb2sect4${element}.$cycle"
export FORT34="$FIXgfs_mos/mdl_gmosxakgb2sect5${element}.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="mdl_gfsgmosak_clip.$cycle"
export FORT60="mdl_gmosxakgb2${element}.$cycle"
startmsg
$EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_ak.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RA2GRIB2 ended 

done

#######################################################################
#  3H TSTMS, CIG AND VIS ONLY AVAILABLE AT 00Z IN EXTENDED CYCLE
#######################################################################

if test $cyc -eq '00'
then

for element in ptstm03 cig vis
do

echo MDLLOG: `date` - begin job RA2GRIB2
export pgm=mdl_ra2grib2
. prep_step
export FORT10="ncepdate"
export FORT31="$FIXgfs_mos/mdl_gmosgb2sect0-1"
export FORT32="$FIXgfs_mos/mdl_gmosakgb2sect3"
export FORT33="$FIXgfs_mos/mdl_gmosxakgb2sect4${element}.$cycle"
export FORT34="$FIXgfs_mos/mdl_gmosxakgb2sect5${element}.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="mdl_gfsgmosak_clip.$cycle"
export FORT60="mdl_gmosxakgb2${element}.$cycle"
startmsg
$EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_ak.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RA2GRIB2 ended

done

fi

#######################################################################
# COPY FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_gfsxmergesta_ak.$cycle $COMOUT
  cpfs mdl_akxdmogrsq.$cycle $COMOUT
  cpfs mdl_akxgoegrsq.$cycle $COMOUT
  cpfs mdl_gfsgmosak.$cycle $COMOUT
  cpfs mdl_gfsxtsvrak47grd.sq.$cycle $COMOUT
  cpfs mdl_gmosxakgb2temp.$cycle $COMOUT
  cpfs mdl_gmosxakgb2dewp.$cycle $COMOUT
  cpfs mdl_gmosxakgb2max.$cycle $COMOUT
  cpfs mdl_gmosxakgb2min.$cycle $COMOUT
  cpfs mdl_gmosxakgb2rh.$cycle $COMOUT
  cpfs mdl_gmosxakgb2ptstm06.$cycle $COMOUT
  cpfs mdl_gmosxakgb2ptstm12.$cycle $COMOUT
  cpfs mdl_gmosxakgb2wspd.$cycle $COMOUT
  cpfs mdl_gmosxakgb2wdir.$cycle $COMOUT
  cpfs mdl_gmosxakgb2wgst.$cycle $COMOUT
  cpfs mdl_gmosxakgb2pop6.$cycle $COMOUT
  cpfs mdl_gmosxakgb2pop12.$cycle $COMOUT
  cpfs mdl_gmosxakgb2sky.$cycle $COMOUT
  cpfs mdl_gmosxakgb2qpf06.$cycle $COMOUT
  cpfs mdl_gmosxakgb2qpf12.$cycle $COMOUT
  cpfs mdl_gmosxakgb2snw24.$cycle $COMOUT
  if test $cyc -eq '00'
  then
    cpfs mdl_gmosxakgb2ptstm03.$cycle $COMOUT
    cpfs mdl_gmosxakgb2cig.$cycle $COMOUT
    cpfs mdl_gmosxakgb2vis.$cycle $COMOUT
  fi
fi

#######################################################################
#  NOW RUN TOCGRIB2 TO PUT HEADERS AND FFS ON THE FILES
#   CAT ALL OF THE GRIB FILES TOGETHER AND RUN TOCGRIB2 ONCE
#   (REMEMBER 3HR TSTM ONLY AT 00Z) 
#######################################################################
touch mdl_gmosxakgrib2.$cycle

for element in temp dewp max min rh ptstm06 ptstm12 wspd wdir wgst pop6 pop12 sky qpf06 qpf12 snw24
do
  cat mdl_gmosxakgb2${element}.$cycle >> mdl_gmosxakgrib2.$cycle
done

if test $cyc -eq '00'
then
  cat mdl_gmosxakgb2ptstm03.$cycle >> mdl_gmosxakgrib2.$cycle
fi

  $GRB2INDEX mdl_gmosxakgrib2.$cycle mdl_gmosxakgrib2i.$cycle

export FORT11="mdl_gmosxakgrib2.$cycle"
export FORT31="mdl_gmosxakgrib2i.$cycle"
export FORT51="mdl_gmosxakgrib2.xtrn.$cycle"

$TOCGRIB2 <$PARMgfs_mos/mdl_gmosxakgb2head.$cycle 1>> $pgmout 2>> errfile

if test $SENDCOM = 'YES'
then
  cpfs mdl_gmosxakgrib2.xtrn.$cycle $COMOUT
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
   export FORT31="$FIXgfs_mos/mdl_gmosgb2sect0-1"
   export FORT32="$FIXgfs_mos/mdl_gmosakgb2sect3"
   export FORT33="$FIXgfs_mos/mdl_gmosxxakgb2sect4${element}.$cycle"
   export FORT34="$FIXgfs_mos/mdl_gmosxxakgb2sect5${element}.$cycle"
   export FORT29="$FIXcode/mdl_mos2000id.tbl"
   export FORT44="mdl_gfsgmosak_clip.$cycle"
   export FORT60="mdl_gmosxxakgb2${element}.$cycle.nohead"
   startmsg
   $EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_ak.cn >> $pgmout 2>errfile
   export err=$?; err_chk
   echo MDLLOG: `date` -  RA2GRIB2 ended

done

#######################################################################
# NOTE: AT THIS POINT IN THE SCRIPT, WE HAVE CREATED GRIB2 FILES
#       WITH NO WMO HEADERS INSERTED. THESE ARE
#
#       mdl_gmosxxakgb2${element}.$cycle.nohead
#
#  NOW RUN TOCGRIB2 TO PUT HEADERS AND FFS ON THE FILES
#  CAT ALL OF THE GRIB FILES TOGETHER AND RUN TOCGRIB2 ONCE
#######################################################################
touch mdl_gmosxxakgrib2.$cycle

for element in temp dewp max min rh pop12 wspd wdir
do
  cat mdl_gmosxxakgb2${element}.$cycle.nohead >> mdl_gmosxxakgrib2.$cycle
done

export pgm=grb2index
. prep_step
startmsg
$GRB2INDEX mdl_gmosxxakgrib2.$cycle mdl_gmosxxakgrib2i.$cycle
export err=$?; err_chk

export pgm=tocgrib2
. prep_step
startmsg
export FORT11="mdl_gmosxxakgrib2.$cycle"
export FORT31="mdl_gmosxxakgrib2i.$cycle"
export FORT51="mdl_gmosxxakgrib2.xtrn.$cycle"
$TOCGRIB2 <$FIXgfs_mos/mdl_gmosxxakgb2head.$cycle 1>> $pgmout 2>> errfile
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
export FORT11="mdl_gmosxxakgb2${element}.$cycle.nohead"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmosxxakgb2${element}.$cycle.temp"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmosxxakgb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

echo `ls -l mdl_gmosxxakgb2${element}.$cycle.temp | awk '{print $5}'` > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmosxxakgb2${element}.$cycle.temp"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmosxxakgb2${element}.xtrn.$cycle"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmosxxakgb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

done

#######################################################################
# COPY "XX" FILES TO COM
#######################################################################

if test $SENDCOM = 'YES'
then
  # ELEMENT-SPECIFIC GRIB2 FILES WITHOUT HEADERS. SENDING TO
  # COM WITHOUT THE .nohead EXTENSION.
  cpfs mdl_gmosxxakgb2temp.$cycle.nohead $COMOUT/mdl_gmosxxakgb2temp.$cycle
  cpfs mdl_gmosxxakgb2dewp.$cycle.nohead $COMOUT/mdl_gmosxxakgb2dewp.$cycle
  cpfs mdl_gmosxxakgb2max.$cycle.nohead $COMOUT/mdl_gmosxxakgb2max.$cycle
  cpfs mdl_gmosxxakgb2min.$cycle.nohead $COMOUT/mdl_gmosxxakgb2min.$cycle
  cpfs mdl_gmosxxakgb2rh.$cycle.nohead $COMOUT/mdl_gmosxxakgb2rh.$cycle
  cpfs mdl_gmosxxakgb2pop12.$cycle.nohead $COMOUT/mdl_gmosxxakgb2pop12.$cycle
  cpfs mdl_gmosxxakgb2wspd.$cycle.nohead $COMOUT/mdl_gmosxxakgb2wspd.$cycle
  cpfs mdl_gmosxxakgb2wdir.$cycle.nohead $COMOUT/mdl_gmosxxakgb2wdir.$cycle
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
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_granlsta_ak.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_ak.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsgrarch_ak.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT43="mdl_gfsgmosak.$cycle"
export FORT60="mdl_gfsgmosaksq.$cycle"
startmsg
$EXECcode/mdl_gridarch < $PARMgfs_mos/mdl_gridarch.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDARCH ended 

#######################################################################
# COPY FILES TO COM
#  FOR ARCHIVING THE GOES, WE'LL SAVE THE U140 OUTPUTS
#######################################################################

if test $SENDCOM = 'YES'
then
  cpfs mdl_gfsgmosaksq.$cycle $COMOUT
fi

#######################################################################
echo MDLLOG: `date` - Job exgfsmos_akgridded_extprdgen has ended.
#######################################################################
