#!/bin/sh
##########################################################################
#  Job Name: exgfsmos_cogridded_extprdgen.skyc.sh.ecf 
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
#
#           NOTE: On approx. 12/13/12, NCO will begin routing 2.5KM CONUS GMOS
#                 GRIB2 files to TOC with superheaders and inidividual headers.
#                 Superheaders will be sents to TGFTP and inidividual headers
#                 will be sent to SBN/NOAAPORT.
##########################################################################
#
PS4='cogridded_extprdgen.skyc $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
set -x

echo MDLLOG: `date` - Begin job exgfsmos_cogridded_extprdgen.skyc

cd $DATA/cogridded/skyc
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
#  COPY THE MDL FORECAST FILES FROM COM
#######################################################################
cpreq $COMIN/mdl_gfsmos.$cycle mdl_gfsmos.$cycle
cpreq $COMIN/mdl_gfscpmos.$cycle mdl_gfscpmos.$cycle
cpreq $COMIN/mdl_goemosxmodel.$cycle mdl_goemosxmodel.$cycle
cpreq $COMIN/mdl_gfsmergesta_co.$cycle mdl_gfsmergesta_co.$cycle
cpreq $COMIN/mdl_goemos.$cycle mdl_goemos.$cycle
cpreq $COMIN/mdl_gfspkd47.$cycle mdl_gfspkd47.$cycle
cpreq $COMIN/mdl_gfsxpkd47.$cycle mdl_gfsxpkd47.$cycle
cat mdl_gfspkd47.$cycle mdl_gfsxpkd47.$cycle >> mdl_gfspkd.$cycle

###########################################################################
#
#    THIS JOB USES THE RANDOM ACCESS FILE FIRST CREATED IN THE
#    EXECUTION OF GFSMOS_COGRIDDED_PRDGEN.  CHECK IF THE FILE MDL_GFSGMOS.TXXZ
#    EXISTS IN COM/GFS.  IF IT DOES, COPY THE FILE TO THE WORK SPACE.
#    IF IT DOES NOT EXIST, THE SCRIPT WILL ABORT.  GFSMOS_COGRIDDED_EXTPRDGEN
#    WILL NOT WORK UNLESS GFSMOS_COGRIDDED_PRDGEN HAS ALREADY RUN SUCCESSFULLY.
#
############################################################################
#
if [ ! -f $COMIN/mdl_gfsgmosco.skyc.$cycle ]
     then echo 'need successful run of gfsmos_cogridded_prdgen to run properly' >> $pgmout
             export err=1;err_chk
fi

cpreq $COMIN/mdl_gfsgmosco.skyc.$cycle .

#######################################################################
#
# PROGRAM RAMERGE - MERGES TWO VECTOR TDLPACK FILES INTO ONE.  IN THIS
#                   CASE MERGE THE METAR AND COOPRFCMESO FILES.
#######################################################################
echo MDLLOG: `date` - begin job RAMERGE

export pgm=mdl_ramerge
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_granlsta_co.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_co.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxramerge_co.skyc.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT46="mdl_gfsmos.$cycle"
export FORT48="mdl_gfscpmos.$cycle"
export FORT60="mdl_gfsxmergesta_co.skyc.$cycle"
$EXECcode/mdl_ramerge < $PARMgfs_mos/mdl_ramerge.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAMERGE ended

#######################################################################
#
# PROGRAM VECT2GRID - CONVERTS SEQUENTIAL "GRIDPOINT STATION" FILE TO
#                     TRUE GRIDDED RECORDS.  THIS RUN PUTS THE CONUS
#                     DMO FOR WIND FIRST GUESS ON THE 5KM CONUS GRID.
#######################################################################
echo MDLLOG: `date` - begin job vect2grid

export pgm=mdl_vect2grid
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_ndfdsta.lst"
export FORT27="$FIXgfs_mos/mdl_ndfdsta.tbl"
export FORT31="$FIXgfs_mos/mdl_gfsxvect2grid_codmo.in.skyc.$cycle"
export FORT32="$FIXgfs_mos/mdl_gfsxvect2grid_codmo.out.skyc.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT61="mdl_goemosxmodel.$cycle"
export FORT60="mdl_cogoedmoxgrsq.skyc.$cycle"
$EXECcode/mdl_vect2grid < $PARMgfs_mos/mdl_vect2grid_codmo.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  VECT2GRID ended

#######################################################################
#
# PROGRAM GRANALYSIS_CO - PERFORMS THE ANALYSIS OF THE MOS FORECASTS
#                         ONTO A GRID.
#
#  NOTE:  THE UPPER AIR DATA FOR LAPSE RATE COMPUTATION COMES FROM
#         THE 95KM MODEL ARCHIVE FILE EXCEPT FOR 183,186,189 WHICH
#         WERE INTERPOLATED TO THE 3KM IN U201.
#######################################################################
echo MDLLOG: `date` - begin job GRANALYSIS_CO

export pgm=mdl_granalysis_co
. prep_step
startmsg
export FORT10="ncepdate"
export FORT17="$FIXgfs_mos/mdl_gmoscobogusfile.sky" 
export FORT18="$FIXgfs_mos/mdl_stationradii_co.sky"
export FORT19="$FIXgfs_mos/mdl_granlstation_cocigpairs"
export FORT26="$FIXgfs_mos/mdl_granlsta_co.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_co.tbl"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="mdl_cogoedmoxgrsq.skyc.$cycle"
export FORT32="mdl_gfspkd.$cycle"
export FORT37="$FIXgfs_mos/mdl_granlstation_copairs"
export FORT38="$FIXgfs_mos/mdl_gfsxgranlids_co.skyc.$cycle"
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_co"
export FORT63="$FIXgfs_mos/mdl_u405acigcocn"
export FORT64="$FIXgfs_mos/mdl_u405askycocn"
export FORT65="$FIXgfs_mos/mdl_u405askycocn"
export FORT80="mdl_gfsmergesta_co.$cycle"
export FORT81="mdl_gfsxmergesta_co.skyc.$cycle"
export FORT42="mdl_gfsgmosco.skyc.$cycle"
$EXECcode/mdl_granalysis_co < $PARMgfs_mos/mdl_granalysis_co.temp.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRANALYSIS ended
#######################################################################
#
# PROGRAM GRIDPOST - PERFORMS POST-PROCESSING OF THE GRIDDED MOS 
#                    FORECASTS. 
#######################################################################
echo MDLLOG: `date` - begin job GRIDPOST - POST PROCESS MOS FORECASTS
export pgm=mdl_gridpost
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_granlsta_co.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_co.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxgrpost_co.skyc.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT42="mdl_gfsgmosco.skyc.$cycle"
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_co.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended 

#######################################################################
echo MDLLOG: `date` - Job gfsmos_cogridded_extprdgen.skyc has ended.
#######################################################################
