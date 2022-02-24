#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_cogridded_prdgen.cig.sh.ecf 
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
#           Mar 2018      GAW    - Split from exgfsmos_cogridded_prdgen.sh.ecf
#                                  for parallel runs of GMOS element groups
#           Nov 07, 2018  JLW    - Adapted script for ceiling
#
#           NOTE: On approx. 12/13/12, NCO will begin routing 2.5KM CONUS GMOS
#                 GRIB2 files to TOC with superheaders and inidividual headers.
#                 Superheaders will be sents to TGFTP and inidividual headers
#                 will be sent to SBN/NOAAPORT.
#######################################################################
#
PS4='cogridded_prdgen.cig $SECONDS +'
set -x
echo MDLLOG: `date` - Begin job exgfsmos_cogridded_prdgen.cig

cd $DATA/cogridded/cig
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"
#######################################################################
#  COPY THE MDL FORECAST FILES FROM COM
#######################################################################
cpreq $COMIN/mdl_gfsmos.$cycle mdl_gfsmos.$cycle
cpreq $COMIN/mdl_gfscpmos.$cycle mdl_gfscpmos.$cycle
cpreq $COMIN/mdl_gfstsvr40.$cycle mdl_gfstsvr40.$cycle
cpreq $COMIN/mdl_goemosmodel.$cycle mdl_goemosmodel.$cycle
cpreq $COMIN/mdl_goemos.$cycle mdl_goemos.$cycle
cpreq $COMIN/mdl_gfspkd47.$cycle mdl_gfspkd.$cycle
cpreq $FIXcode/mdl_rafile_template mdl_grd2grd_co.cig.$cycle

echo MDLLOG: `date` - begin job RAMERGE

export pgm=mdl_ramerge
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE FILE
export FORT26="$FIXgfs_mos/mdl_granlsta_co.lst"                                    #INPUT STATION LIST
export FORT27="$FIXgfs_mos/mdl_granlsta_co.tbl"                                    #INPUT STATION TABLE
export FORT28="$FIXgfs_mos/mdl_gfsramerge_co.cig.$cycle"                           #INPUT VARIABLE LIST  ?
export FORT29="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT46="mdl_gfsmos.$cycle"
export FORT48="mdl_gfscpmos.$cycle"
export FORT60="mdl_gfsmergesta_co.cig.$cycle"
$EXECcode/mdl_ramerge < $PARMgfs_mos/mdl_ramerge.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAMERGE ended

#######################################################################
#
# PROGRAM GRD2GRD - INTERPOLATE MODEL GRIDS FOR CEILING FIRST GUESS
#
#######################################################################
echo MDLLOG: `date` - begin job grd2grd

export pgm=mdl_grd2grd
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE FILE
export FORT25="mdl_gfspkd.$cycle"
export FORT28="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT27="$FIXgfs_mos/mdl_gfsgrd2grd_cig.ids.$cycle"                          #INPUT ID LIST
export FORT42="mdl_grd2grd_co.cig.$cycle"
$EXECcode/mdl_grd2grd < $PARMgfs_mos/mdl_grd2grd_co.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - GRD2GRD ended
$EXECcode/itdlp mdl_grd2grd_co.cig.$cycle -tdlp  mdl_grd2grd_co_sq.cig.$cycle
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
export FORT24="mdl_grd2grd_co_sq.cig.$cycle"                                   #OUTPUT SEQUENTIAL FILE
export FORT26="$FIXgfs_mos/mdl_granlsta_co.lst"                                    #INPUT STATION LIST
export FORT27="$FIXgfs_mos/mdl_granlsta_co.tbl"                                    #INPUT STATION TABLE
export FORT28="$FIXgfs_mos/mdl_gfsgrpost_cig.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_co"                                 #INPUT GRIDDED CONSTANT FILE
export FORT30="mdl_grpost_co.cig.$cycle"
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_cig.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended

#######################################################################
#
# PROGRAM GRANALYSIS_CO - PERFORMS THE ANALYSIS OF THE MOS FORECASTS
#                         ONTO A GRID.
#
# FIRST: COPY THE RANDOM ACCESS TEMPLATE FILE FROM FIX. WE DON'T HAVE
#        GFSXMERGESTA YET SO TOUCH THE FILE TO CREATE IT.
#
#  NOTE: THE UPPER AIR DATA FOR LAPSE RATE COMPUTATION COMES FROM
#        THE 95KM MODEL ARCHIVE FILE
#######################################################################
cpreq $FIXcode/mdl_rafile_template_large mdl_gfsgmosco.cig.$cycle

touch mdl_gfsxmergesta_co.$cycle

echo MDLLOG: `date` - begin job GRANALYSIS_CO
export pgm=mdl_granalysis_co
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE LIST
export FORT17="$FIXgfs_mos/mdl_gmoscobogusfile.cig"                                #INPUT BOGUS LIST
export FORT18="$FIXgfs_mos/mdl_stationradii_co.cig"                                #INPUT RADII FILE
export FORT26="$FIXgfs_mos/mdl_granlsta_co_cig.lst"                                #INPUT STATION LIST
export FORT27="$FIXgfs_mos/mdl_granlsta_co.tbl"                                    #INPUT STATION TABLE
export FORT29="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT GRIDDED CONSTANT FILE
export FORT30="mdl_grpost_co.cig.$cycle"                                       #INPUT FIRST GUESS GRIDS
export FORT32="mdl_gfspkd.$cycle"                                              #INPUT STATION FORECASTS
export FORT37="$FIXgfs_mos/mdl_granlstation_cocigpairs"                            #INPUT STATION PAIRS
export FORT38="$FIXgfs_mos/mdl_gfsgranlids_co.cig.$cycle"                          #INPUT ID LIST
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_co"                                 #INPUT GRIDDED CONSTANT FILE
export FORT63="$FIXgfs_mos/mdl_u405acigcocn"                                       #INPUT U405A CONTROL FILE
export FORT80="mdl_gfsmergesta_co.cig.$cycle"
export FORT81="mdl_gfsxmergesta_co.$cycle"
export FORT42="mdl_gfsgmosco.cig.$cycle"
$EXECcode/mdl_granalysis_co < $PARMgfs_mos/mdl_granalysis_co.vis.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRANALYSIS_CO ended
#######################################################################
#
# PROGRAM GRIDPOST - PERFORMS POST-PROCESSING OF THE GRIDDED MOS
#                    FORECASTS.
#######################################################################
echo MDLLOG: `date` - begin job GRIDPOST - POST PROCESS MOS FORECASTS

export pgm=mdl_gridpost
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE LIST
export FORT26="$FIXgfs_mos/mdl_granlsta_co.lst"                                    #INPUT STATION LIST
export FORT27="$FIXgfs_mos/mdl_granlsta_co.tbl"                                    #INPUT STATION TABLE
export FORT28="$FIXgfs_mos/mdl_gfsgrpost_co.cig.$cycle"                            #INPUT ID LIST
export FORT29="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT42="mdl_gfsgmosco.cig.$cycle"
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_co.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended

########################################################################
## COPY FILES TO COM
########################################################################
#
if test $SENDCOM = 'YES'
then
  ## TDLPACK FILES
  cpfs mdl_gfsmergesta_co.cig.$cycle $COMOUT
  cpfs mdl_gfsgmosco.cig.$cycle $COMOUT
fi
#
#######################################################################
echo MDLLOG: `date` - Job exgfsmos_cogridded_prdgen.cig has ended.
#######################################################################
