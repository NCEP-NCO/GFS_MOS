#!/bin/sh
#######################################################################
#  Job Name: exgfsmos_akgridded_prdgen.vis.sh.ecf 
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
#
#######################################################################
#
set -x
PS4='akgridded_prdgen.vis $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_akgridded_prdgen.vis

cd $DATA/akgridded/vis
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
#  COPY THE MDL FORECAST FILES FROM COM
#    3/2008 - Right now we need the AK thunderstorm file, the station
#             MOS forecasts(METAR and coop), the first guess from the 
#             AK goe jobs, and the previous-cycle's station data.
#    9/2008 - Now we need to get the goe ra file too, and the GFS
#             model file for the wind lapse rates
#######################################################################
cpreq $COMIN/mdl_gfsmos.$cycle mdl_gfsmos.$cycle
cpreq $COMIN/mdl_gfscpmos.$cycle mdl_gfscpmos.$cycle
cpreq $COMIN/mdl_gfstsvrak47.$cycle mdl_gfstsvrak47.$cycle
cpreq $COMIN/mdl_goeakmosmodel.$cycle mdl_goeakmosmodel.$cycle
cpreq $COMIN/mdl_goeakmos.$cycle mdl_goeakmos.$cycle
cpreq $COMIN/mdl_gfspkd47.$cycle mdl_gfspkd.$cycle
cpreq $FIXcode/mdl_rafile_template mdl_grd2grd_ak.vis.$cycle
cpreq $COMIN/mdl_gfspkdgmosak.$cycle mdl_gfspkdgmosak.$cycle


#######################################################################
#
# PROGRAM RAMERGE - MERGES TWO VECTOR TDLPACK FILES INTO ONE.  IN THIS
#                   CASE MERGE THE METAR AND COOPRFCMESO FILES.
#######################################################################
echo MDLLOG: `date` - begin job RAMERGE

export pgm=mdl_ramerge
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE LIST
export FORT26="$FIXgfs_mos/mdl_granlsta_ak.vis.lst"                                #INPUT STATION LIST
export FORT27="$FIXgfs_mos/mdl_granlsta_ak.tbl"                                    #INPUT STATION TABLE
export FORT28="$FIXgfs_mos/mdl_gfsramerge_ak.vis.$cycle"                           #INPUT ID LIST
export FORT29="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT46="mdl_gfsmos.$cycle"
export FORT48="mdl_gfscpmos.$cycle"
export FORT60="mdl_gfsmergesta_ak.vis.$cycle"
$EXECcode/mdl_ramerge < $PARMgfs_mos/mdl_ramerge.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAMERGE ended

#######################################################################
#
# PROGRAM GRD2GRD - INTERPOLATE MODLE VISIBILITY FOR FIRST GUESS
#
#######################################################################
echo MDLLOG: `date` - begin job grd2grd

export pgm=mdl_grd2grd
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE LIST
export FORT25="mdl_gfspkdgmosak.$cycle"                                        
export FORT28="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT27="$FIXgfs_mos/mdl_gfsgrd2grd_vis.ids.$cycle"                          #INPUT VARIABLE LIST
export FORT42="mdl_grd2grd_ak.vis.$cycle"
$EXECcode/mdl_grd2grd < $PARMgfs_mos/mdl_grd2grd_ak47.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - GRD2GRD ended
$EXECcode/itdlp mdl_grd2grd_ak.vis.$cycle -tdlp  mdl_grd2grd_ak_sq.vis.$cycle
export err=$?; err_chk


#######################################################################
#
# PROGRAM GRANALYSIS_AK - PERFORMS THE ANALYSIS OF THE MOS FORECASTS
#                      ONTO A GRID.
#   FIRST:  COPY THE RANDOM ACCESS TEMPLATE FILE FROM FIX
#    WE DON'T HAVE GFSXMERGESTA YET SO TOUCH THE FILE TO CREATE IT
#
#  NOTE:  THE UPPER AIR DATA FOR LAPSE RATE COMPUTATION COMES FROM
#         THE 95KM MODEL ARCHIVE FILE
#######################################################################
cpreq $FIXcode/mdl_rafile_template mdl_gfsgmosak.vis.$cycle

touch mdl_gfsxmergesta_ak.$cycle

echo MDLLOG: `date` - begin job GRANALYSIS
export pgm=mdl_granalysis_ak
. prep_step
startmsg
export FORT10="ncepdate"                                                       #INPUT DATE LIST
export FORT26="$FIXgfs_mos/mdl_granlsta_ak.vis.lst"                                #INPUT STATION LIST
export FORT27="$FIXgfs_mos/mdl_granlsta_ak.tbl"                                    #INPUT STATION TABLE
export FORT18="$FIXgfs_mos/mdl_stationradii_ak.vis"                                #INPUT RADII FILE
export FORT29="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT30="mdl_akdmogrsq.$cycle"                                           #OUTPUT SEQUENTIAL FILE
export FORT36="$FIXgfs_mos/mdl_gmosakbogusfile.vis"                                #INPUT BOGUS LIS
export FORT32="mdl_gfspkd.$cycle"
export FORT37="$FIXgfs_mos/mdl_granlstation_akvispairs"                            #INPUT STATION PAIRS
export FORT38="$FIXgfs_mos/mdl_gfsgranlids_ak.vis.$cycle"                          #INPUT ID LIST
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_ak"                                 #INPUT GRIDDED CONSTANT FILE
export FORT63="$FIXgfs_mos/mdl_u405avisakcn"                                       #INPUT CONTROL FILE
export FORT80="mdl_gfsmergesta_ak.vis.$cycle"
export FORT81="mdl_gfsxmergesta_ak.$cycle"
export FORT42="mdl_gfsgmosak.vis.$cycle"
export FORT31="mdl_grd2grd_ak_sq.vis.$cycle"
$EXECcode/mdl_granalysis_co < $PARMgfs_mos/mdl_granalysis_ak.vis.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRANALYSIS_AK ended

#######################################################################
#
# PROGRAM GRIDPOST - PERFORMS POST-PROCESSING OF THE GRIDDED MOS 
#                    FORECASTS. 
#  Note:  This run of gridpost outputs to both unit 42 (random access)
#         and unit 60 which is sequential.  This is because grd2grd can 
#         only have sequential input and we need to expand the AK grid 
#         from that produced by U155 to the 1.8 million NDFD points.
#######################################################################
echo MDLLOG: `date` - begin job GRIDPOST - POST PROCESS MOS FORECASTS
export pgm=mdl_gridpost
. prep_step
export FORT10="ncepdate"                                                       #INPUT DATE LIST
export FORT26="$FIXgfs_mos/mdl_granlsta_ak.vis.lst"                                #INPUT STATION LIST
export FORT27="$FIXgfs_mos/mdl_granlsta_ak.tbl"                                    #INPUT STATION TABLE
export FORT28="$FIXgfs_mos/mdl_gfsgrpost_ak.vis.$cycle"                            #INPUT ID LIST
export FORT29="$FIXcode/mdl_mos2000id.tbl"                                     #INPUT MOS2000 ID TABLE
export FORT42="mdl_gfsgmosak.vis.$cycle"
export FORT60="mdl_gfsgmosaksq_pp.vis.$cycle"
startmsg
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_ak.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended 

########################################################################
## COPY FILES TO COM
########################################################################
#
if test $SENDCOM = 'YES'
then
  cpfs mdl_gfsmergesta_ak.vis.$cycle $COMOUT
  cpfs mdl_gfsgmosak.vis.$cycle $COMOUT
  cpfs mdl_gfsgmosaksq_pp.vis.$cycle $COMOUT
fi
#
#######################################################################
echo MDLLOG: `date` - Job exgfsmos_akgridded_prdgen.temp has ended.
#######################################################################
