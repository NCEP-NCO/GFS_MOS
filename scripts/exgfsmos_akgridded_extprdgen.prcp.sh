#!/bin/sh
##########################################################################
#  Job Name: exgfsmos_akgridded_extprdgen.prcp.sh.ecf 
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
#
##########################################################################
#
PS4='akgridded_extprdgen.prcp $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_akgridded_extprdgen.prcp

set -x

cd $DATA/akgridded/prcp
cpreq $DATA/ncepdate .

echo $PDY $cyc: Date and Cycle - echo PDY and cyc

export DAT="$PDY$cyc"

#######################################################################
#  COPY THE MDL FORECAST FILES FROM COM
#    3/2008 - Right now we need the thunderstorm file, the station
#             MOS forecasts(METAR and coop), the first guess from the 
#             AK goe jobs, and the previous-cycle's station data.
#    9/2008 - Now we need to get the goe ra file too and the GFS model
#             file.
#######################################################################
cpreq $COMIN/mdl_gfsmos.$cycle mdl_gfsmos.$cycle
cpreq $COMIN/mdl_gfscpmos.$cycle mdl_gfscpmos.$cycle
cpreq $COMIN/mdl_goeakmosxmodel.$cycle mdl_goeakmosxmodel.$cycle
cpreq $COMIN/mdl_gfstsvrak47.$cycle mdl_gfstsvrak47.$cycle
cpreq $COMIN/mdl_gfsmergesta_ak.$cycle mdl_gfsmergesta_ak.$cycle
cpreq $COMIN/mdl_goeakmos.$cycle mdl_goeakmos.$cycle
cat $COMIN/mdl_gfspkd47.$cycle $COMIN/mdl_gfsxpkd47.$cycle >gfspkdfull.$cycle
cpreq $COMIN/mdl_pkgfsxxrawgmosak.$cycle gfsxxpkdtimtrp.$cycle

###########################################################################
#
#    THIS JOB USES THE RANDOM ACCESS FILE FIRST CREATED IN THE
#    EXECUTION OF GFSMOS_AKGRIDDED_PRDGEN.  CHECK IF THE FILE MDL_GFSGMOSAK.TXXZ
#    EXISTS IN COM/GFS.  IF IT DOES, COPY THE FILE TO THE WORK SPACE.
#    IF IT DOES NOT EXIST, THE SCRIPT WILL ABORT.  GFSMOS_AKGRIDDED_EXTPRDGEN
#    WILL NOT WORK UNLESS GFSMOS_AKGRIDDED_PRDGEN HAS ALREADY RUN SUCCESSFULLY.
#
############################################################################
#
if [ ! -f $COMIN/mdl_gfsgmosak.prcp.$cycle ]
     then echo 'need successful run of gfsmos_akgridded_prdgen.prcp to run properly' >> $pgmout
             export err=1;err_chk
fi

cpreq $COMIN/mdl_gfsgmosak.prcp.$cycle .

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
export FORT26="$FIXgfs_mos/mdl_granlsta_ak.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_ak.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxramerge_ak.prcp.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT46="mdl_gfsmos.$cycle"
export FORT48="mdl_gfscpmos.$cycle"
export FORT60="mdl_gfsxmergesta_ak.prcp.$cycle"
$EXECcode/mdl_ramerge < $PARMgfs_mos/mdl_ramerge.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RAMERGE ended

#######################################################################
#
# PROGRAM VECT2GRID - CONVERTS SEQUENTIAL "GRIDPOINT STATION" FILE TO
#                     TRUE GRIDDED RECORDS.  THIS RUN PUTS THE AK
#                     GOES FOR POP/QPF AND SKY ON THE 3KM AK GRID.
#######################################################################
echo MDLLOG: `date` - begin job vect2grid

export pgm=mdl_vect2grid
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_akndfdsta.lst"
export FORT27="$FIXgfs_mos/mdl_akndfdsta.tbl"
export FORT31="$FIXgfs_mos/mdl_gfsxvect2grid_akgoe.in.prcp.$cycle"
export FORT32="$FIXgfs_mos/mdl_gfsxvect2grid_akgoe.out.prcp.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT48="mdl_goeakmos.$cycle"
export FORT60="mdl_akxgoegrsq.prcp.$cycle"
$EXECcode/mdl_vect2grid < $PARMgfs_mos/mdl_vect2grid_akgoe.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  VECT2GRID ended


#######################################################################
#
# PROGRAM GRANALYSIS_AK - PERFORMS THE ANALYSIS OF THE MOS FORECASTS
#                      ONTO A GRID.
#
#  NOTE:  THE UPPER AIR DATA FOR LAPSE RATE COMPUTATION COMES FROM
#         THE 95KM MODEL ARCHIVE FILE EXCEPT FOR 183,186,189 WHICH
#         WERE INTERPOLATED TO THE 3KM IN U201.
#######################################################################

echo MDLLOG: `date` - begin job GRANALYSIS
export pgm=mdl_granalysis_ak
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_granlsta_ak.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_ak.tbl"
export FORT17="$FIXgfs_mos/mdl_stationradii_ak.pqpf"
export FORT19="$FIXgfs_mos/mdl_stationradii_ak.snow"
export FORT22="$FIXgfs_mos/mdl_gmosakbogusfile.pop"
export FORT23="$FIXgfs_mos/mdl_akaugpairs_qpf"
export FORT24="$FIXgfs_mos/mdl_akaugpairs_snow"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT30="mdl_akxgoegrsq.prcp.$cycle"
export FORT32="gfspkdfull.$cycle"
export FORT33="gfsxxpkdtimtrp.$cycle"
export FORT37="$FIXgfs_mos/mdl_granlstation_akpairs"
export FORT38="$FIXgfs_mos/mdl_gfsxgranlids_ak.prcp.$cycle"
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_ak"
export FORT51="$FIXgfs_mos/mdl_u405adewakcn"
export FORT53="$FIXgfs_mos/mdl_u405atmpakcn"
export FORT54="$FIXgfs_mos/mdl_u405amaxakcn"
export FORT55="$FIXgfs_mos/mdl_u405aminakcn"
export FORT56="$FIXgfs_mos/mdl_u405apop6akcn"
export FORT57="$FIXgfs_mos/mdl_u405apop12akcn"
export FORT64="$FIXgfs_mos/mdl_u405aqpf6akcn"
export FORT65="$FIXgfs_mos/mdl_u405aqpf6ak1cn"
export FORT66="$FIXgfs_mos/mdl_u405aqpf12akcn"
export FORT67="$FIXgfs_mos/mdl_u405asnwakcn"
export FORT80="mdl_gfsmergesta_ak.$cycle"
export FORT81="mdl_gfsxmergesta_ak.prcp.$cycle"
export FORT42="mdl_gfsgmosak.prcp.$cycle"
$EXECcode/mdl_granalysis_co < $PARMgfs_mos/mdl_granalysis_ak.elem.cn >> $pgmout 2>errfile
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
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_granlsta_ak.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta_ak.tbl"
export FORT28="$FIXgfs_mos/mdl_gfsxgrpost_ak.prcp.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT42="mdl_gfsgmosak.prcp.$cycle"
export FORT60="mdl_gfsxgmosaksq.prcp.$cycle"
startmsg
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_ak.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended 

#######################################################################
echo MDLLOG: `date` - Job exgfsmos_akgridded_extprdgen.prcp has ended.
#######################################################################
