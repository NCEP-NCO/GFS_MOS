#!/bin/sh
#
#######################################################################
#  Job Name: exgfsmos_cowx_prdgen.sh 
#  Purpose: To run all steps necessary to create GFS-based gridded 
#           MOS Predominant Weather fcsts on the CONUS 2.5 km NDFD Grid.
#
#  Remarks: None
#
#  HISTORY: 2012-03-28  Huntemann  MDL  New job for CONUS 2.5 km Gridded
#                                       MOS weather. Adapted from 2.5 km
#                                       Gridded MOS prdgen scripts.
#           2013-11-15  Huntemann  MDL  Updated for operations.
#           2013-12-04  Scallion   MDL  Removed sleep. Copy GMOS input
#                                       into working (DATA) directory.
#           2014-01-14  Engle      Added tocgrib2super program and dbn_alert
#                                  commands; removed 2 instances of RACREATE
#                                  that were being run before RA2GRIB2.
#           2015-06-29  Scallion   MDL  Trim GMOS elements used in 
#                                       mdl_wxgrid so they match expected
#                                       grid.
#           2016-02-08  Scallion   MDL  Configured for MPMD. Also run itdlp
#                                       before mdl_granalysis_ak in order 
#                                       to make the needed sequential file.
#######################################################################
PS4='cowx_prdgen $SECONDS +'
#PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'

echo MDLLOG: `date` - Begin job `basename $0`
set -x

cd $DATA/cowx
cpreq $DATA/ncepdate .

#######################################################################
# COPY GMOS DATA INTO WORKING DIRECTORY
#######################################################################
cpreq $COMIN/mdl_gfsgmosco.${cycle} .
cpreq $COMIN/mdl_gfsgmoscotstm_grsq.${cycle} .
cpreq $COMIN/mdl_gfspopo3_grsq.${cycle} .
cpreq $COMIN/mdl_gfsptype_grsq.${cycle} .
cpreq $COMIN/mdl_gfstsvr_grsq.${cycle} .

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
export FORT50="mdl_wxgrid_gfsgmosco.${cycle}"
$EXECcode/mdl_racreate < $PARMcode/mdl_u350.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  RACREATE ended

#######################################################################
#
# PROGRAM ITDLP - CREATE SEQUENTIAL FILE OF SHORT-RANGE GMOS
#
#######################################################################
export FORT20="mdl_gfsgmosco.$cycle"
export FORT21="mdl_gfsgmoscosq.$cycle"

$EXECcode/itdlp $FORT20 -tdlp $FORT21 >> $pgmout 2>errfile
export err=$?; err_chk

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
export FORT30="mdl_gfsgmoscosq.${cycle}"
export FORT44="$FIXgfs_mos/mdl_analysisgrconst_gmos2p5"
export FORT31="mdl_cogmoswxtrim_grsq.$PDY$cyc"
export FORT26="$FIXgfs_mos/mdl_granlsta.lst"
export FORT27="$FIXgfs_mos/mdl_granlsta.tbl"
export FORT38="$FIXgfs_mos/mdl_gfswxgranlids_co.$cycle"
export FORT51="$FIXgfs_mos/mdl_u405atmpwxcocn"
export FORT52="$FIXgfs_mos/mdl_u405adptwxcocn"
export FORT53="$FIXgfs_mos/mdl_u405apop6wxcocn"
export FORT54="$FIXgfs_mos/mdl_u405aqpf6wxcocn"
export FORT55="$FIXgfs_mos/mdl_u405apop12wxcocn"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
$EXECcode/mdl_granalysis_ak < $PARMgfs_mos/mdl_granalysis_cowxtrim.cn >> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  GRANALYSIS ended

# Check for HR-QPF file
if [ -s $COMIN/mdl_hrqpf_gfsgmoscosq.$cycle ]; then
   cat mdl_cogmoswxtrim_grsq.$PDY$cyc $COMIN/mdl_hrqpf_gfsgmoscosq.$cycle > mdl_cogmoswxtrim_grsq.$cycle
else
   cpreq mdl_cogmoswxtrim_grsq.$PDY$cyc mdl_cogmoswxtrim_grsq.$cycle
fi

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
export FORT24="$FIXgfs_mos/mdl_u720wxcocn"                          # external weather grid control file
export FORT28="$FIXgfs_mos/mdl_wxgridprd.${cycle}"                  # input variable list
export FORT32="$FIXcode/mdl_station.lst"                        # station list
export FORT33="$FIXcode/mdl_station.tbl"                        # station table
export FORT34="$FIXcode/mdl_mos2000id.tbl"                      # id table.
export FORT35="mdl_wxkeys_cotxt.${cycle}"                       # output ascii keylist
export FORT43="mdl_wxgrid_gfsgmosco.${cycle}"                   # random access gridded output
export FORT75="mdl_gfsgmoscotstm_grsq.${cycle}"                 # grsq non-jigsaw u155 tstm input
export FORT76="mdl_cogmoswxtrim_grsq.${cycle}"                  # grsq GMOS Input from GRD2GRD
export FORT77="mdl_gfspopo3_grsq.${cycle}"                      # grsq popo3
export FORT78="mdl_gfsptype_grsq.${cycle}"                      # grsq ptype
export FORT79="mdl_gfstsvr_grsq.$cycle"                         # grsq tsvr run by oper
$EXECcode/mdl_wxgrid < $PARMgfs_mos/mdl_wxgridco.cn>> $pgmout 2>errfile
export err=$?; err_chk
echo MDLLOG: `date` -  WXGRID ended 
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
export FORT32="mdl_wxkeys_cotxt.${cycle}"
export FORT33="$FIXgfs_mos/mdl_gmoscowxgb2sect3"
export FORT34="$FIXgfs_mos/mdl_gmoscogb2sect4wx.${cycle}"
export FORT35="$FIXgfs_mos/mdl_gmoscogb2sect5wx.${cycle}"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="mdl_wxgrid_gfsgmosco.${cycle}"
export FORT60="mdl_gmoscogb2wx.${cycle}.nohead"
$EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_cowx.cn >> $pgmout 2>errfile
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
export FORT32="$FIXgfs_mos/mdl_gmoscowxgb2sect3"
export FORT33="$FIXgfs_mos/mdl_gmoscogb2sect4ppi.${cycle}"
export FORT34="$FIXgfs_mos/mdl_gmoscogb2sect5ppi.${cycle}"
export FORT29="$FIXcode/mdl_mos2000id.tbl"
export FORT44="mdl_wxgrid_gfsgmosco.${cycle}"
export FORT60="mdl_gmoscogb2ppi.${cycle}.nohead"
$EXECcode/mdl_ra2grib2 < $PARMgfs_mos/mdl_ra2grib2_co.cn >> $pgmout 2>errfile
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
export FORT11="mdl_gmoscogb2${element}.$cycle.nohead"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmoscogb2${element}.$cycle.temp"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmoscogb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

echo `ls -l mdl_gmoscogb2${element}.$cycle.temp | awk '{print $5}'` > filesize
export pgm=tocgrib2super
. prep_step
startmsg
export FORT11="mdl_gmoscogb2${element}.$cycle.temp"
export FORT12="filesize"
export FORT31=
export FORT51="mdl_gmoscogb2${element}.xtrn.$cycle"
$TOCGRIB2SUPER < $FIXgfs_mos/mdl_gmoscogb2head${element}.$cycle 1>> $pgmout 2>> errfile
export err=$?; err_chk

done
#
########################################################################
# COPY FILES TO COM
########################################################################

if test $SENDCOM = 'YES'
then
   # SEND GRIB2 FILE WITH NO HEADERS TO $COMOUT
   cpfs mdl_gmoscogb2ppi.$cycle.nohead $COMOUT/mdl_gmoscogb2ppi.$cycle
   cpfs mdl_gmoscogb2wx.$cycle.nohead $COMOUT/mdl_gmoscogb2wx.$cycle
fi

########################################################################
echo MDLLOG: `date` - End job `basename $0`
########################################################################
