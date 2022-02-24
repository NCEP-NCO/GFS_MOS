#!/bin/sh
#######################################################################
#
#  Job Name: exgfsmos_prgridded_prdgen.sh.ecf 
#
#   Purpose: To run all steps necessary to create short range GFS-based
#            gridded MOS fcsts on the HI NDGD grid
#
#   Remarks: This script is kicked off when the 4 forecast jobs
#            METAR, PRGOE, COOPMESO, and TSTM have completed. 
#            The goe and gridded forecasts are archived in the 
#            extended-range job.
#
#   History: Aug 18, 2010  EFE - New job for PR Gridded MOS (short-range).
#                                Adapted from exgfsmos_akgridded_prdgen.sh.sms
#                                This initial implementation of PR Gridded
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
#######################################################################
#
set -x
PS4='prgridded_prdgen $SECONDS +'
echo MDLLOG: `date` - Begin job exgfsmos_prgridded_prdgen

cd $DATA/prgridded
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="${PDY}${cyc}"
#######################################################################
#  COPY THE MDL FORECAST FILES FROM COM
#######################################################################
cpreq $COMIN/mdl_gfsmos.$cycle mdl_gfsmos.$cycle
cpreq $COMIN/mdl_gfscpmos.$cycle mdl_gfscpmos.$cycle
cpreq $COMIN/mdl_gfspkd47.$cycle mdl_gfspkd47.$cycle
cpreq $FIXcode/mdl_rafile_template mdl_grd2grd_pr.$cycle

#######################################################################
# PROGRAM RAMERGE - MERGES TWO VECTOR TDLPACK FILES INTO ONE.  IN THIS
#                   CASE MERGE THE METAR AND COOPRFCMESO FILES.
#######################################################################
echo MDLLOG: `date` - begin job RAMERGE

export pgm=mdl_ramerge
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_granlsta_pr.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_pr.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsramerge_pr.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT46="mdl_gfsmos.$cycle"
export FORT48="mdl_gfscpmos.$cycle"
export FORT60="mdl_gfsmergesta_pr.$cycle"
$EXECcode/mdl_ramerge < $PARMgfs_mos/mdl_ramerge.cn >> $pgmout 2> errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAMERGE ended
#######################################################################
#
# PROGRAM GRD2GRD - INTERPOLATE MODEL VISIBILITY FOR FIRST GUESS
#
#######################################################################
echo MDLLOG: `date` - begin job grd2grd

export pgm=mdl_grd2grd
. prep_step
startmsg
export FORT10="ncepdate"
export FORT25="mdl_gfspkd47.$cycle"
export FORT28="$FIXcode/mdl_mos2000id.tbl"
export FORT27="$FIXgfs_mos/mdl_gfsgrd2grd.ids.$cycle"
export FORT42="mdl_grd2grd_pr.$cycle"
$EXECcode/mdl_grd2grd < $PARMgfs_mos/mdl_grd2grd_pr.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - GRD2GRD ended
$EXECcode/itdlp mdl_grd2grd_pr.$cycle -tdlp  mdl_grd2grd_pr_sq.$cycle
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
export FORT10="ncepdate"
export FORT24="mdl_grd2grd_pr_sq.$cycle"
export FORT26="$FIXgfs_mos/mdl_granlsta_pr.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_pr.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsgrpost_cig.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_pr"
export FORT30="mdl_grpost_pr.cig.$cycle"
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_cig.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended

#######################################################################
#
# PROGRAM GRANALYSIS_PR - PERFORMS THE ANALYSIS OF THE MOS FORECASTS
#                         ONTO A GRID.
#
# FIRST: COPY THE RANDOM ACCESS TEMPLATE FILE FROM FIX WE DON'T HAVE
#        GFSXMERGESTA YET SO TOUCH THE FILE TO CREATE IT.
#
# NOTE: THE UPPER AIR DATA FOR LAPSE RATE COMPUTATION COMES FROM
#       THE PUERTO RICO SUBGRID 47.625KM GFS MOS ARCHIVE.
#######################################################################
cpreq $FIXcode/mdl_rafile_template mdl_gfsgmospr.$cycle

touch mdl_gfsxmergesta_pr.$cycle

echo MDLLOG: `date` - begin job GRANALYSIS_PR
# Use mdl_granalysis_hi
export pgm=mdl_granalysis_pr
. prep_step
startmsg
export FORT10="ncepdate"
export FORT23="$FIXgfs_mos/mdl_gmosprbogusfile.vis"
export FORT18="$FIXgfs_mos/mdl_station_radii_prcig"
export FORT19="$FIXgfs_mos/mdl_station_radii_prvis"
export FORT26="$FIXgfs_mos/mdl_granlsta_pr.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_pr.tbl"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="mdl_grpost_pr.cig.$cycle"
export FORT31="mdl_grd2grd_pr_sq.$cycle"
export FORT32="mdl_gfspkd47.$cycle"
export FORT37="$FIXgfs_mos/mdl_granlstation_prcigpairs"
export FORT38="$FIXgfs_mos/mdl_gfsgranlids_pr.$cycle"
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_pr"
export FORT63="$FIXgfs_mos/mdl_u405avisprcn"
export FORT64="$FIXgfs_mos/mdl_u405acigprcn"
export FORT80="mdl_gfsmergesta_pr.$cycle"
export FORT81="mdl_gfsxmergesta_pr.$cycle"
export FORT42="mdl_gfsgmospr.$cycle"

$EXECcode/mdl_granalysis_co < $PARMgfs_mos/mdl_granalysis_pr.cn >> $pgmout 2> errfile
export err=$?; err_chk

echo MDLLOG: `date` -  GRANALYSIS_PR ended
#######################################################################
# PROGRAM GRIDPOST - PERFORMS POST-PROCESSING OF THE GRIDDED MOS 
#                    FORECASTS. 
#######################################################################
echo MDLLOG: `date` - begin job GRIDPOST - POST PROCESS MOS FORECASTS

export pgm=mdl_gridpost
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_granlsta_pr.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_pr.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsgrpost_pr.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT42="mdl_gfsgmospr.$cycle"

$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost.cn >> $pgmout 2> errfile
export err=$?; err_chk

echo MDLLOG: `date` -  GRIDPOST ended 
#######################################################################
# PROGRAM RA2GRIB2 - CODES TDLPACK MOS FORECASTS INTO GRIB2. 
#######################################################################
for element in cig vis
do

   echo MDLLOG: `date` - begin job RA2GRIB2 

   export pgm=mdl_ra2grib2
   . prep_step
   startmsg
   export FORT10="ncepdate"                                                       #INPUT DATE LIST
   export FORT31="$FIXgfs_mos/mdl_gmosgb2sect0-1"
   export FORT32="$FIXgfs_mos/mdl_gmosprgb2sect3"
   export FORT33="$FIXgfs_mos/mdl_gmosprgb2sect4${element}.$cycle"
   export FORT34="$FIXgfs_mos/mdl_gmosprgb2sect5${element}.$cycle"
   export FORT29="$FIXcode/mdl_mos2000id.tbl"
   export FORT44="mdl_gfsgmospr.$cycle"
   export FORT60="mdl_gmosprgb2${element}.$cycle.nohead"

   $EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_pr.cn >> $pgmout 2> errfile
   export err=$?; err_chk

   echo MDLLOG: `date` -  RA2GRIB2 ended 

done
#######################################################################
# COPY FILES TO COM
#######################################################################
if test $SENDCOM = 'YES'
then

  cpfs mdl_gfsmergesta_pr.$cycle $COMOUT
  cpfs mdl_gfsgmospr.$cycle $COMOUT
  cpfs mdl_gmosprgb2cig.$cycle.nohead $COMOUT/mdl_gmosprgb2cig.$cycle
  cpfs mdl_gmosprgb2vis.$cycle.nohead $COMOUT/mdl_gmosprgb2vis.$cycle

fi
#######################################################################
echo MDLLOG: `date` - Job exgfsmos_prgridded_prdgen has ended.
#######################################################################
