#!/bin/sh
##########################################################################
#  Job Name: exgfsmos_akgridded_extprdgen.tstm.sh.ecf 
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
PS4='akgridded_extprdgen.tstm $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
echo MDLLOG: `date` - Begin job exgfsmos_akgridded_extprdgen.tstm

set -x

cd $DATA/akgridded/tstm
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
cpreq $COMIN/mdl_gfstsvrak47.$cycle mdl_gfstsvrak47.$cycle
cpreq $COMIN/mdl_gfsmergesta_ak.$cycle mdl_gfsmergesta_ak.$cycle
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
if [ ! -f $COMIN/mdl_gfsgmosak.tstm.$cycle ]
     then echo 'need successful run of gfsmos_akgridded_prdgen.tstm to run properly' >> $pgmout
             export err=1;err_chk
fi

cpreq $COMIN/mdl_gfsgmosak.tstm.$cycle .

#######################################################################
#
# PROGRAM VECT2GRID - CONVERTS SEQUENTIAL "GRIDPOINT STATION" FILE 
#         (U140)      TO TRUE GRIDDED RECORDS.  THIS RUN PUTS THE AK 
#                     47KM TSTMS INTO GRIDDED FORMAT.
#######################################################################
echo MDLLOG: `date` - begin job vect2grid

export pgm=mdl_vect2grid
. prep_step
startmsg
export FORT10="ncepdate"
export FORT26="$FIXgfs_mos/mdl_tsvrak47sta.lst"
export FORT27="$FIXgfs_mos/mdl_tsvrak47sta.tbl"
export FORT31="$FIXgfs_mos/mdl_gfsxvect2grid_tsvrak47.in.$cycle"
export FORT32="$FIXgfs_mos/mdl_gfsxvect2grid_tsvrak47.out.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT48="mdl_gfstsvrak47.$cycle"
export FORT60="mdl_gfsxtsvrak47grd.sq.$cycle"
$EXECcode/mdl_vect2grid < $PARMgfs_mos/mdl_vect2grid_tsvrak47.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  VECT2GRID ended 

#######################################################################
# PROGRAM GRD2GRD - INTERPOLATE DATA FROM AK 47KM GRID TO 3KM U155 GRID
#         (U365)
#######################################################################
echo MDLLOG: `date` - begin job GRD2GRD - INTERPOLATE TO NDFD GRID

export pgm=mdl_grd2grd
. prep_step
startmsg
export FORT10="ncepdate"
export FORT25="mdl_gfsxtsvrak47grd.sq.$cycle"
export FORT28="$FIXcode/mdl_mos2000id.tbl"
export FORT27="$FIXgfs_mos/mdl_gfsxgrd2grd_tsvrak47.ids.$cycle"
export FORT42="mdl_gfsgmosak.tstm.$cycle"
$EXECcode/mdl_grd2grd < $PARMgfs_mos/mdl_grd2grd_ak47.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - GRD2GRD ended

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
export FORT28="$FIXgfs_mos/mdl_gfsxgrpost_ak.tstm.$cycle"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT42="mdl_gfsgmosak.tstm.$cycle"
export FORT60="mdl_gfsxgmosaksq.tstm.$cycle"
startmsg
$EXECcode/mdl_gridpost < $PARMgfs_mos/mdl_gridpost_ak.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRIDPOST ended 

#######################################################################
echo MDLLOG: `date` - Job exgfsmos_akgridded_extprdgen.tstm has ended.
#######################################################################
