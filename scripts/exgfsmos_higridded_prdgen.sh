#!/bin/sh
#######################################################################
#
#  Job Name: exgfsmos_higridded_prdgen.sh.ecf 
#
#   Purpose: To run all steps necessary to create short range GFS-based
#            gridded MOS fcsts on the HI NDGD grid
#
#   Remarks: This script is kicked off when the 4 forecast jobs
#            METAR, HIGOE, COOPMESO, and TSTM have completed. 
#            The goe and gridded forecasts are archived in the 
#            extended-range job.
#
#   History: Aug 18, 2010  EFE - New job for HI Gridded MOS (short-range).
#                                Adapted from exgfsmos_akgridded_prdgen.sh.sms
#                                This initial implementation of HI Gridded
#                                MOS contains the following elements: 
#                                2-m Temp, Dew, MaxT, MinT, Wind Speed, Wind
#                                Direction, Wind Gust, 6-hr POP, 12-hr POP,
#                                and RH.
#            Nov  2, 2010  EFE - Corrected section of script that
#                                inserts WMO superheader and individual
#                                headers into GRIB2 files. Headers will
#                                now be inserted into the element-specific
#                                GRIB2 files, then cat the files into
#                                one large GRIB2 (xtrn) file. This is
#                                file that will alerted to TOC via db_net.
#            Dec 03, 2012  EFE - Transitioned to WCOSS (Linux). Changed
#                                all 'XLFUNIT_  ' env vars to 'FORT  '
#            Feb 05, 2016  SDS - Configured for MPMD
#            Oct 05, 2018  JLW - Added visibility grids
#            Jul 26, 2019  SDS - Removed dissemination of grids.    
#######################################################################
#
set -x
PS4='higridded_prdgen $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_higridded_prdgen

cd $DATA/higridded
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="${PDY}${cyc}"
#######################################################################
#  WAIT 10 MINUTES (600 SECONDS) BEFORE CONTINUING.  WHEN MORE
#  FIELDS ARE ADDED TO GRIDDED HI MOS, THIS SLEEP WILL BE REDUCED AND
#  EVENTUALLY REMOVED.
#######################################################################
#sleep 600
#######################################################################
#  COPY THE MDL FORECAST FILES FROM COM
#######################################################################
cpreq $COMIN/mdl_gfsmos.$cycle mdl_gfsmos.$cycle
cpreq $COMIN/mdl_gfscpmos.$cycle mdl_gfscpmos.$cycle
cpreq $COMIN/mdl_gfstsvrak47.$cycle mdl_gfstsvrak47.$cycle
cpreq $COMIN/mdl_goehimosmodel.$cycle mdl_goehimosmodel.$cycle
cpreq $COMIN/mdl_goehimos.$cycle mdl_goehimos.$cycle
cpreq $COMIN/mdl_gfspkd47.$cycle mdl_gfspkd47.$cycle
cpreq $FIXcode/mdl_rafile_template mdl_grd2grd_hi.vis.$cycle

#######################################################################
# PROGRAM RAMERGE - MERGES TWO VECTOR TDLPACK FILES INTO ONE.  IN THIS
#                   CASE MERGE THE METAR AND COOPRFCMESO FILES.
#######################################################################
echo MDLLOG: `date` - begin job RAMERGE

export pgm=mdl_ramerge
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE LIST
export FORT26="$FIXgfs_mos/mdl_granlsta_hi.lst"                                    #INPUT STATION LIST
export FORT27="$FIXgfs_mos/mdl_granlsta_hi.tbl"                                    #INPUT STATION TABLE
export FORT28="$FIXgfs_mos/mdl_gfsramerge_hi.$cycle"                               #INPUT ID LIST
export FORT29="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT46="mdl_gfsmos.$cycle"
export FORT48="mdl_gfscpmos.$cycle"
export FORT60="mdl_gfsmergesta_hi.$cycle"
$EXECcode/mdl_ramerge < $PARMgfs_mos/mdl_ramerge.cn >> $pgmout 2> errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAMERGE ended
#######################################################################
# PROGRAM VECT2GRID - CONVERTS SEQUENTIAL "GRIDPOINT STATION" FILE TO
#                     TRUE GRIDDED RECORDS.  THIS RUN PUTS THE HI
#                     DMO FOR TEMP AND WIND FIRST GUESS ON THE 2.5KM HI 
#                     GRID.
#######################################################################
echo MDLLOG: `date` - begin job vect2grid

export pgm=mdl_vect2grid
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE LIST
export FORT26="$FIXgfs_mos/mdl_hindfdtrimsta.lst"                                  #INPUT STATION LIST
export FORT27="$FIXgfs_mos/mdl_hindfdtrimsta.tbl"                                  #INPUT STATION TABLE
export FORT31="$FIXgfs_mos/mdl_gfsvect2grid_hidmo.in.$cycle"                       #INPUT VARIABLE LIST
export FORT32="$FIXgfs_mos/mdl_gfsvect2grid_hidmo.out.$cycle"                      #INPUT VARIABLE LIST
export FORT29="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT61="mdl_goehimosmodel.$cycle"
export FORT60="mdl_hidmogrsq.$cycle"

$EXECcode/mdl_vect2grid < $PARMgfs_mos/mdl_vect2grid_hidmo.cn >> $pgmout 2> errfile
export err=$?; err_chk

echo MDLLOG: `date` -  VECT2GRID ended
#######################################################################
# PROGRAM VECT2GRID - CONVERTS SEQUENTIAL "GRIDPOINT STATION" FILE TO
#                     TRUE GRIDDED RECORDS.  THIS RUN PUTS THE HI
#                     GOES FOR POP ON THE 2.5KM HI GRID.
#######################################################################
echo MDLLOG: `date` - begin job vect2grid

export pgm=mdl_vect2grid
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE LIST
export FORT26="$FIXgfs_mos/mdl_hindfdtrimsta.lst"                                  #INPUT STATION LIST
export FORT27="$FIXgfs_mos/mdl_hindfdtrimsta.tbl"                                  #INPUT STATION TABLE
export FORT31="$FIXgfs_mos/mdl_gfsvect2grid_higoe.in.$cycle"                       #INPUT VARIABLE LIST
export FORT32="$FIXgfs_mos/mdl_gfsvect2grid_higoe.out.$cycle"                      #INPUT VARIABLE LIST
export FORT29="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT48="mdl_goehimos.$cycle"
export FORT60="mdl_higoegrsq.$cycle"

$EXECcode/mdl_vect2grid < $PARMgfs_mos/mdl_vect2grid_higoe.cn >> $pgmout 2> errfile
export err=$?; err_chk

echo MDLLOG: `date` -  VECT2GRID ended
#######################################################################
#
# PROGRAM GRD2GRD - INTERPOLATE MODEL VISIBILITY FOR FIRST GUESS
#
#######################################################################
echo MDLLOG: `date` - begin job grd2grd

export pgm=mdl_grd2grd
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE LIST
export FORT25="mdl_gfspkd47.$cycle"
export FORT28="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT27="$FIXgfs_mos/mdl_gfsgrd2grd_vis.ids.$cycle"                          #INPUT VARIABLE LIST
export FORT42="mdl_grd2grd_hi.vis.$cycle"
$EXECcode/mdl_grd2grd < $PARMgfs_mos/mdl_grd2grd_hi.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - GRD2GRD ended
$EXECcode/itdlp mdl_grd2grd_hi.vis.$cycle -tdlp  mdl_grd2grd_hi_sq.vis.$cycle
export err=$?; err_chk

#######################################################################
#
# PROGRAM GRD2GRD - INTERPOLATE MODLE VISIBILITY FOR FIRST GUESS
#
#######################################################################
echo MDLLOG: `date` - begin job grd2grd

export pgm=mdl_grd2grd
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE LIST                                                       #INPUT DATE FILE
export FORT25="mdl_gfspkd47.$cycle"                                            #
export FORT28="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT27="$FIXgfs_mos/mdl_gfsgrd2grd_cig.ids.$cycle"                          #INPUT ID LIST
export FORT42="mdl_grd2grd_hi.vis.$cycle"                                      #
$EXECcode/mdl_grd2grd < $PARMgfs_mos/mdl_grd2grd_hi.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - GRD2GRD ended

# Flip to sequential for U155/catting on to DMO file
$EXECcode/itdlp mdl_grd2grd_hi.vis.$cycle -tdlp  mdl_grd2grd_hi_sq.cigin.$cycle
export err=$?; err_chk

#######################################################################
#
# PROGRAM GRIDPOST - PERFORMS POST-PROCESSING OF THE TDLPACK GFS MODEL
#                    DATA.
#######################################################################
echo MDLLOG: `date` - begin job GRIDPOST - POST PROCESS MOS FORECASTS

export pgm=mdl_gridpost
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE LIST
export FORT24="mdl_grd2grd_hi_sq.cigin.$cycle"                                 #INPUT SQ FILE
export FORT26="$FIXgfs_mos/mdl_granlsta_ak.vis.lst"                                #INPUT STATION LIS
export FORT27="$FIXgfs_mos/mdl_granlsta_ak.tbl"                                    #INPUT STATION TABLE
export FORT28="$FIXgfs_mos/mdl_gfsgrpost_cig.$cycle"                               #INPUT ID LIST
export FORT29="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_hi"                                 #INPUT GRIDDED CONSTANT FILE
export FORT30="mdl_grpost_hi.cig.$cycle"                                       #OUTPUT GRIDDED FORECAST ?
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_cig.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended

cat mdl_grpost_hi.cig.$cycle >> mdl_grd2grd_hi_sq.vis.$cycle

cat mdl_grd2grd_hi_sq.vis.$cycle >> mdl_hidmogrsq.$cycle

#######################################################################
# PROGRAM GRANALYSIS_HI - PERFORMS THE ANALYSIS OF THE MOS FORECASTS
#                         ONTO A GRID.
#
# FIRST: COPY THE RANDOM ACCESS TEMPLATE FILE FROM FIX WE DON'T HAVE
#        GFSXMERGESTA YET SO TOUCH THE FILE TO CREATE IT.
#
# NOTE: THE UPPER AIR DATA FOR LAPSE RATE COMPUTATION COMES FROM
#       THE HAWAII SUBGRID 47.625KM GFS MOS ARCHIVE.
#######################################################################
cpreq $FIXcode/mdl_rafile_template mdl_gfsgmoshi.$cycle

touch mdl_gfsxmergesta_hi.$cycle

echo MDLLOG: `date` - begin job GRANALYSIS_HI
export pgm=mdl_granalysis_hi
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE LIST
export FORT26="$FIXgfs_mos/mdl_granlsta_hi.lst"                                    #INPUT STATION LIST
export FORT27="$FIXgfs_mos/mdl_granlsta_hi.tbl"                                    #INPUT STATION TABLE
export FORT15="$FIXgfs_mos/mdl_station_radii_hi"                                   #INPUT RADII FILE
export FORT16="$FIXgfs_mos/mdl_station_radii_hiwind"                               #INPUT RADII FILE
export FORT17="$FIXgfs_mos/mdl_station_radii_hipop"                                #INPUT RADII FILE
export FORT21="$FIXgfs_mos/mdl_gmoshibogusfile.wind"                               #INPUT BOGUS LIST
export FORT22="$FIXgfs_mos/mdl_gmoshibogusfile.pop"                                #INPUT BOGUS LIST
export FORT29="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT30="mdl_hidmogrsq.$cycle"                                           #OUTPUT SEQUENTIAL FILE
export FORT31="mdl_higoegrsq.$cycle"                                           #OUTPUT SEQUENTIAL FILE
export FORT32="mdl_gfspkd47.$cycle"
export FORT37="$FIXgfs_mos/mdl_granlstation_hipairs"                               #INPUT STATION PAIRS
export FORT38="$FIXgfs_mos/mdl_gfsgranlids_hi.$cycle"                              #INPUT ID LIST
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_hi"                                 #INPUT GRIDDED CONSTANT FILE
export FORT51="$FIXgfs_mos/mdl_u405adewhicn"                                       #INPUT CONTROL FILE
export FORT53="$FIXgfs_mos/mdl_u405atmphicn"                                       #INPUT CONTROL FILE
export FORT54="$FIXgfs_mos/mdl_u405amaxhicn"                                       #INPUT CONTROL FILE
export FORT55="$FIXgfs_mos/mdl_u405aminhicn"                                       #INPUT CONTROL FILE
export FORT56="$FIXgfs_mos/mdl_u405apop6hicn"                                      #INPUT CONTROL FILE
export FORT57="$FIXgfs_mos/mdl_u405apop12hicn"                                     #INPUT CONTROL FILE
export FORT58="$FIXgfs_mos/mdl_u405awuhicn"                                        #INPUT CONTROL FILE
export FORT59="$FIXgfs_mos/mdl_u405awvhicn"                                        #INPUT CONTROL FILE
export FORT60="$FIXgfs_mos/mdl_u405awspdhicn"                                      #INPUT CONTROL FILE
export FORT61="$FIXgfs_mos/mdl_u405awdirhicn"                                      #INPUT CONTROL FILE
export FORT62="$FIXgfs_mos/mdl_u405awgsthicn"                                      #INPUT CONTROL FILE
export FORT63="$FIXgfs_mos/mdl_u405avishicn"                                       #INPUT CONTROL FILE
export FORT80="mdl_gfsmergesta_hi.$cycle"
export FORT81="mdl_gfsxmergesta_hi.$cycle"
export FORT42="mdl_gfsgmoshi.$cycle"

$EXECcode/mdl_granalysis_hi < $PARMgfs_mos/mdl_granalysis_hi.cn >> $pgmout 2> errfile
export err=$?; err_chk
#
# Ceiling and Visibility use the mdl_granalysis_co executable
#
export pgm=mdl_granalysis_hi
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE LIST
export FORT26="$FIXgfs_mos/mdl_granlsta_hi_cv.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_hi_cv.tbl"
export FORT18="$FIXgfs_mos/mdl_station_radii_hivis"
export FORT21="$FIXgfs_mos/mdl_gmoshibogusfile.wind"
export FORT22="$FIXgfs_mos/mdl_gmoshibogusfile.pop"
export FORT23="$FIXgfs_mos/mdl_gmoshibogusfile.vis"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="mdl_hidmogrsq.$cycle"
export FORT31="mdl_higoegrsq.$cycle"
export FORT32="mdl_gfspkd47.$cycle"
export FORT33="mdl_grd2grd_hi_sq.vis.$cycle"
export FORT35="ascii.out"
export FORT37="$FIXgfs_mos/mdl_granlstation_hivispairs"
export FORT38="$FIXgfs_mos/mdl_gfsgranlids_hi.cv.$cycle"
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_hi"
export FORT63="$FIXgfs_mos/mdl_u405avishicn"
export FORT64="$FIXgfs_mos/mdl_u405acighicn"
export FORT80="mdl_gfsmergesta_hi.$cycle"
export FORT81="mdl_gfsxmergesta_hi.$cycle"
export FORT42="mdl_gfsgmoshi.$cycle"
export FORT45="mdl_grd2grd_hi.vis.$cycle"

$EXECcode/mdl_granalysis_co < $PARMgfs_mos/mdl_granalysis_hi_cv.cn >> $pgmout 2> errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRANALYSIS_HI ended
#######################################################################
# PROGRAM GRIDPOST - PERFORMS POST-PROCESSING OF THE GRIDDED MOS 
#                    FORECASTS. 
#######################################################################
echo MDLLOG: `date` - begin job GRIDPOST - POST PROCESS MOS FORECASTS

export pgm=mdl_gridpost
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE LIST
export FORT26="$FIXgfs_mos/mdl_granlsta_hi.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_hi.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsgrpost_hi.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT42="mdl_gfsgmoshi.$cycle"

$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost.cn >> $pgmout 2> errfile
export err=$?; err_chk

echo MDLLOG: `date` -  GRIDPOST ended
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
for element in temp dewp max min rh wspd wdir wgst pop12 pop6 cig vis
do

   echo MDLLOG: `date` - begin job RA2GRIB2 

   export pgm=mdl_ra2grib2
   . prep_step
   startmsg
   export FORT10="ncepdate"                                                       #INPUT DATE LIST
   export FORT31="$FIXgfs_mos/mdl_gmosgb2sect0-1"
   export FORT32="$FIXgfs_mos/mdl_gmoshigb2sect3"
   export FORT33="$FIXgfs_mos/mdl_gmoshigb2sect4${element}.$cycle"
   export FORT34="$FIXgfs_mos/mdl_gmoshigb2sect5${element}.$cycle"
   export FORT29="$FIXcode/mdl_mos2000id.tbl"
   export FORT44="mdl_gfsgmoshi.$cycle"
   export FORT60="mdl_gmoshigb2${element}.$cycle.nohead"

   $EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_hi.cn >> $pgmout 2> errfile
   export err=$?; err_chk

   echo MDLLOG: `date` -  RA2GRIB2 ended 

done
#######################################################################
# UTILITY AQM_SMOKE - INSERTS WMO SUPERHEADERS AND INDIVIDUAL HEADERS
#                     INTO ELEMENT-SPECIFIC GRIB2 FILES, THEN CAT ALL
#                     ELEMENT-SPECIFIC GRIB2 FILES INTO ONE FILE.
#
# NOTE:  THOUGH THE NAME DOES NOT SUGGEST IT, AQM_SMOKE IS AN UPDATED
#        VERSION OF TOCGRIB2. THIS UPDATED VERSION CAN NOW INSERT WMO
#        SUPERHEADERS INTO A GRIB2 FILE.
#######################################################################
touch mdl_gmoshigrib2.xtrn.$cycle
for element in temp dewp max min rh wspd wdir wgst pop12 pop6
do

echo 0 > filesize
export FORT11="mdl_gmoshigb2${element}.$cycle.nohead"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmoshigb2${element}.$cycle.temp"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmoshigb2head${element}.$cycle 1>> $pgmout 2>> errfile

echo `ls -l mdl_gmoshigb2${element}.$cycle.temp | awk '{print $5}'` > filesize
export FORT11="mdl_gmoshigb2${element}.$cycle.temp"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmoshigb2${element}.$cycle"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmoshigb2head${element}.$cycle 1>> $pgmout 2>> errfile

cat mdl_gmoshigb2${element}.$cycle >> mdl_gmoshigrib2.xtrn.$cycle

done
#######################################################################
# COPY FILES TO COM
#######################################################################
if test $SENDCOM = 'YES'
then

  cpfs mdl_gfsmergesta_hi.$cycle $COMOUT
  cpfs mdl_hidmogrsq.$cycle $COMOUT
  cpfs mdl_higoegrsq.$cycle $COMOUT
  cpfs mdl_grd2grd_hi.vis.$cycle $COMOUT
  cpfs mdl_gfsgmoshi.$cycle $COMOUT
  cpfs mdl_gmoshigb2temp.$cycle $COMOUT
  cpfs mdl_gmoshigb2dewp.$cycle $COMOUT
  cpfs mdl_gmoshigb2max.$cycle $COMOUT
  cpfs mdl_gmoshigb2min.$cycle $COMOUT
  cpfs mdl_gmoshigb2rh.$cycle $COMOUT
  cpfs mdl_gmoshigb2wspd.$cycle $COMOUT
  cpfs mdl_gmoshigb2wdir.$cycle $COMOUT
  cpfs mdl_gmoshigb2wgst.$cycle $COMOUT
  cpfs mdl_gmoshigb2pop6.$cycle $COMOUT
  cpfs mdl_gmoshigb2pop12.$cycle $COMOUT
  cpfs mdl_gmoshigrib2.xtrn.$cycle $COMOUT
  cpfs mdl_gmoshigb2cig.$cycle.nohead $COMOUT/mdl_gmoshigb2cig.$cycle
  cpfs mdl_gmoshigb2vis.$cycle.nohead $COMOUT/mdl_gmoshigb2vis.$cycle

fi
#######################################################################
echo MDLLOG: `date` - Job exgfsmos_higridded_prdgen has ended.
#######################################################################
