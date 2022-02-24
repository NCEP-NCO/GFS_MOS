#!/bin/sh
#
#######################################################################
#  Job Name: exgfsmos_akwx_extprdgen.sh.ecf
#  Purpose: To run all steps necessary to create GFS-based gridded 
#           MOS Predominant Weather fcsts on the CONUS 2.5 km NDFD Grid.
#
#  Remarks: None
#
#  HISTORY: 2012-08-27  Huntemann  MDL   New job for Alaska Gridded
#                                        MOS weather. Adapted from 2.5 km
#                                        Gridded MOS prdgen scripts.
#           2013-11-19  Huntemann  MDL  Updated for operations.
#           2013-12-04  Scallion   MDL  Removed sleep. Copy input GMOS 
#                                       file into working directory.
#           2014-01-02  Shafer     MDL   Modified ptype and popo3
#                                        input file names for ext-range.
#           2014-01-14  Engle      Added tocgrib2super program and dbn_alert
#                                  commands; removed 2 instances of RACREATE
#                                  that were being run before RA2GRIB2.
#           2016-02-10  Scallion   Configured for MPMD
#           2016-04-13  G.Wagner   MDL  Added run of MDL_GRANALYSIS_AK to
#                                       trim expanded AK GMOS output to
#                                       extent expected by all the Wx Inputs.
#           2019-07-26  Scallion   MDL  Removed dissemination of grids.  
#######################################################################
PS4='akwx_extprdgen $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'

echo MDLLOG: `date` - Begin job `basename $0`
set -x

cd $DATA/akwx
cpreq $DATA/ncepdate .

#######################################################################
#  COPY ALASKA GMOS FILE FROM COM
#######################################################################
cpreq $COMIN/mdl_gfsgmosaksq.${cycle} .
cpreq $COMIN/mdl_akgfsxpopo3_grsq.${cycle} .
cpreq $COMIN/mdl_akgfsxptype_grsq.${cycle} .

#
#######################################################################
#
# PROGRAM RACREATE - MOS-2000 PROGRAM WHICH
#                    CREATES RANDOM ACCESS FILES; IN THIS CASE, THE
#                    CODE IS USED TO CREATE THE OPERATIONAL MOS
#                    FORECAST FILE.
#  (U350)
#######################################################################
#
echo MDLLOG: `date` - begin job RACREATE - CREATE MOS FORECAST FILE
export pgm=mdl_racreate
. prep_step
startmsg
export FORT50="mdl_wxgrid_gfsgmosxak.${cycle}"
$EXECcode/mdl_racreate < $PARMcode/mdl_u350.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RACREATE ended

#
#######################################################################
#
# PROGRAM GRANALYSIS - ANALYZE WX ELEMENTS TO "UN-EXPANDED" 2.5 KM GRID
#                      (THIS IS REALLY JUST RUNNING A SMOOTHER)
#
#######################################################################
#
echo MDLLOG: `date` - begin job GRANALYSIS
export pgm=mdl_granalysis_ak
. prep_step
startmsg
export FORT10="ncepdate"
export FORT30="mdl_gfsgmosaksq.${cycle}"
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_akwx"
export FORT31="mdl_akgmoswxtrim_grsq.$PDY$cyc"
export FORT26="$FIXgfs_mos/mdl_granlsta.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta.tbl"
export FORT38="$FIXgfs_mos/mdl_gfsxwxgranlids_ak.$cycle"
export FORT51="$FIXgfs_mos/mdl_u405atmpwxakcn"
export FORT52="$FIXgfs_mos/mdl_u405adptwxakcn"
export FORT53="$FIXgfs_mos/mdl_u405apop6wxakcn"
export FORT54="$FIXgfs_mos/mdl_u405aqpf6wxakcn"
export FORT55="$FIXgfs_mos/mdl_u405apop12wxakcn"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
$EXECcode/mdl_granalysis_ak < $PARMgfs_mos/mdl_granalysis_akwxtrim.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRANALYSIS ended

cpreq mdl_akgmoswxtrim_grsq.$PDY$cyc mdl_akgmoswxtrim_grsq.$cycle

#
#######################################################################
#
# PROGRAM WXGRID - USED TO GENERATE MOS WEATHER GRID AND PPI FROM
#                  LOTS OF GMOS INPUTS
#  (U720)
#######################################################################
#
echo MDLLOG: `date` - begin job WXGRID - GENERATE MOS WEATHER GRID
export pgm=mdl_wxgrid
. prep_step
startmsg
export FORT10="ncepdate"
export FORT24="$FIXgfs_mos/mdl_u720wxakcn"                          # external weather grid control file
export FORT28="$FIXgfs_mos/mdl_wxgridxprd.${cycle}"                 # input variable list
export FORT31="mdl_wxgrid_gfsgmosxaksq.${cycle}"                # sequential gridded output
export FORT32="$FIXcode/mdl_station.lst"                        # station list
export FORT33="$FIXcode/mdl_station.tbl"                        # station table
export FORT34="$FIXcode/mdl_mos2000id.tbl"                      # id table.
export FORT35="mdl_wxkeysx_aktxt.${cycle}"                      # output ascii keylist
export FORT43="mdl_wxgrid_gfsgmosxak.${cycle}"                  # random access gridded output
export FORT76="mdl_akgmoswxtrim_grsq.${cycle}"                  # grsq GMOS Input
export FORT77="mdl_akgfsxpopo3_grsq.${cycle}"                   # grsq popo3      PS 2014-01-02: ext-range file name
export FORT78="mdl_akgfsxptype_grsq.${cycle}"                   # grsq ptype      PS 2014-01-02: ext-range file name
$EXECcode/mdl_wxgrid < $PARMgfs_mos/mdl_wxgridak.cn>> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  WXGRID ended 
#
#######################################################################
#
# PROGRAM RACREATE - MOS-2000 PROGRAM WHICH
#                    CREATES RANDOM ACCESS FILES; IN THIS CASE, THE
#                    CODE IS USED TO CREATE THE OPERATIONAL MOS
#                    FORECAST FILE.
#  (U350)
#######################################################################
#
echo MDLLOG: `date` - begin job RACREATE - CREATE MOS GRIB2 FILE
export pgm=mdl_racreate
. prep_step
startmsg
export FORT50="mdl_wxgrid_gfsgmosxakndfd.$cycle"
$EXECcode/mdl_racreate < $PARMcode/mdl_u350.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RACREATE ended
#
#######################################################################
# PROGRAM GRD2GRD - INTERPOLATE DATA TO NDFD GRID
#         (U365)    
#######################################################################
echo MDLLOG: `date` - begin job GRD2GRD - INTERPOLATE TO NDFD GRID

export pgm=mdl_grd2grd
. prep_step
startmsg
export FORT10="ncepdate"
export FORT25="mdl_wxgrid_gfsgmosxaksq.$cycle"
export FORT28="$FIXcode/mdl_mos2000id.tbl"
export FORT27="$FIXgfs_mos/mdl_wxgridxprd.$cycle"
export FORT42="mdl_wxgrid_gfsgmosxakndfd.$cycle" # grd2grd makes RA, U365 makes sq
$EXECcode/mdl_grd2grd < $PARMgfs_mos/mdl_grd2grd_akndfd.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` - GRD2GRD ended
#
#######################################################################
#
# PROGRAM RA2GRIB2 - CODES TDLPACK MOS FORECASTS INTO GRIB2. (WX)
#  (U135)
#######################################################################
#
echo MDLLOG: `date` - begin job RA2GRIB2 - GENERATE GRIB2 FILE
export pgm=mdl_ra2grib2
. prep_step
startmsg
export FORT10="ncepdate"
export FORT31="$FIXgfs_mos/mdl_gmosgb2sect0-1wx"
export FORT32="mdl_wxkeysx_aktxt.${cycle}"
export FORT33="$FIXgfs_mos/mdl_gmosakgb2sect3"
export FORT34="$FIXgfs_mos/mdl_gmosxakgb2sect4wx.${cycle}"
export FORT35="$FIXgfs_mos/mdl_gmosxakgb2sect5wx.${cycle}"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="mdl_wxgrid_gfsgmosxakndfd.${cycle}"
export FORT60="mdl_gmosxakgb2wx.${cycle}.nohead"
$EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_akwx.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RA2GRIB2 ended 
#
#######################################################################
#
# PROGRAM RA2GRIB2 - CODES TDLPACK MOS FORECASTS INTO GRIB2. (PPI)
#  (U135)
#######################################################################
#
echo MDLLOG: `date` - begin job RA2GRIB2 - GENERATE GRIB2 FILE
export pgm=mdl_ra2grib2
. prep_step
startmsg
export FORT10="ncepdate"
export FORT31="$FIXgfs_mos/mdl_gmosgb2sect0-1wx"
export FORT32="$FIXgfs_mos/mdl_gmosakgb2sect3"
export FORT33="$FIXgfs_mos/mdl_gmosxakgb2sect4ppi.${cycle}"
export FORT34="$FIXgfs_mos/mdl_gmosxakgb2sect5ppi.${cycle}"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="mdl_wxgrid_gfsgmosxakndfd.${cycle}"
export FORT60="mdl_gmosxakgb2ppi.${cycle}.nohead"
$EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_ak.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RA2GRIB2 ended 
#
#######################################################################
# UTILITY TOCGRIB2SUPER - INSERTS WMO SUPERHEADERS AND INDIVIDUAL HEADERS
#                         INTO ELEMENT-SPECIFIC GRIB2 FILES, THEN CAT ALL
#                         ELEMENT-SPECIFIC GRIB2 FILES INTO ONE FILE.
#######################################################################
#
for element in ppi wx
do

echo 0 > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmosxakgb2${element}.$cycle.nohead"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmosxakgb2${element}.$cycle.temp"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmosxakgb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

echo `ls -l mdl_gmosxakgb2${element}.$cycle.temp | awk '{print $5}'` > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmosxakgb2${element}.$cycle.temp"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmosxakgb2${element}.xtrn.$cycle"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmosxakgb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

done
#
########################################################################
# COPY FILES TO COM
########################################################################

if test $SENDCOM = 'YES'
then
   # SEND GRIB2 FILE WITH NO HEADERS TO $COMOUT
   cpfs mdl_gmosxakgb2ppi.$cycle.nohead $COMOUT/mdl_gmosxakgb2ppi.$cycle
   cpfs mdl_gmosxakgb2wx.$cycle.nohead $COMOUT/mdl_gmosxakgb2wx.$cycle
fi

#######################################################################
echo MDLLOG: `date` - End job `basename $0`
#######################################################################
