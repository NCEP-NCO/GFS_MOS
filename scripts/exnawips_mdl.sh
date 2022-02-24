#!/bin/ksh
###################################################################
echo "----------------------------------------------------"
echo "exnawips - convert NCEP GRIB files into GEMPAK Grids"
echo "----------------------------------------------------"
echo "History: Mar 2000 - First implementation of this new script."
echo "S Lilly: May 2008 - add logic to make sure that all of the "
echo "                    data produced from the restricted ECMWF"
echo "                    data on the CCS is properly protected."
echo "C. Magee: 10/2013 - swap X and Y for rtgssthr Atl and Pac."
#####################################################################

PS4='${PMI_FORK_RANK} $SECONDS ${0/\/gpfs\/hps\/nco\/ops\/nw.*\/gfs_mos.*\/scripts/} +'
set -xa

cd $DATA

msg="Begin job for $job"
postmsg "$jlogfile" "$msg"

#
NAGRIB_TABLE=${NAWIPS}/../fix/nagrib.tbl
NAGRIB=nagrib_nc
#

entry=`grep "^$RUN " $NAGRIB_TABLE | awk 'index($1,"#") != 1 {print $0}'`

if [ "$entry" != "" ] ; then
  cpyfil=`echo $entry  | awk 'BEGIN {FS="|"} {print $2}'`
  garea=`echo $entry   | awk 'BEGIN {FS="|"} {print $3}'`
  gbtbls=`echo $entry  | awk 'BEGIN {FS="|"} {print $4}'`
  maxgrd=`echo $entry  | awk 'BEGIN {FS="|"} {print $5}'`
  kxky=`echo $entry    | awk 'BEGIN {FS="|"} {print $6}'`
  grdarea=`echo $entry | awk 'BEGIN {FS="|"} {print $7}'`
  proj=`echo $entry    | awk 'BEGIN {FS="|"} {print $8}'`
  output=`echo $entry  | awk 'BEGIN {FS="|"} {print $9}'`
else
  cpyfil=gds
  garea=dset
  gbtbls=
  maxgrd=4999
  kxky=
  grdarea=
  proj=
  output=T
fi  
pdsext=no

maxtries=180
fhcnt=$fstart
while [ $fhcnt -le $fend ] ; do
  if [ $fhcnt -ge 100 ] ; then
    typeset -Z3 fhr
  else
    typeset -Z2 fhr
  fi
  fhr=$fhcnt
  fhcnt3=`expr $fhr % 3`

  fhr3=$fhcnt
  typeset -Z3 fhr3
  GRIBIN=$COMIN/${RUN}.${cycle}.${GRIB}${fhr}${EXT}
  GEMGRD=${RUN}_${PDY}${cyc}f${fhr3}

  case $RUN in
   mdlgfssvr) GRIBIN=$COMIN/mdl_mavgribtsvr.${cycle}
           GEMGRD=${RUN}_${PDY}${cyc} ;;
   mdlmrfsvr) GRIBIN=$COMIN/mdl_mexgribtsvr.${cycle}
           GEMGRD=${RUN}_${PDY}${cyc} ;;
  esac

  GRIBIN_chk=$GRIBIN

  cp $GRIBIN grib$fhr

  export pgm="nagrib_nc F$fhr"
  startmsg

  $GEMEXE/$NAGRIB << EOF
   GBFILE   = grib$fhr
   INDXFL   = 
   GDOUTF   = $GEMGRD
   PROJ     = $proj
   GRDAREA  = $grdarea
   KXKY     = $kxky
   MAXGRD   = $maxgrd
   CPYFIL   = $cpyfil
   GAREA    = $garea
   OUTPUT   = $output
   GBTBLS   = $gbtbls
   GBDIAG   = 
   PDSEXT   = $pdsext
  l
  r
EOF
  export err=$?;err_chk

  #####################################################
  # GEMPAK DOES NOT ALWAYS HAVE A NON ZERO RETURN CODE
  # WHEN IT CAN NOT PRODUCE THE DESIRED GRID.  CHECK
  # FOR THIS CASE HERE.
  #####################################################
  if [ $RUN != "ukmet_early" ] ; then
    ls -l $GEMGRD
    export err=$?;export pgm="GEMPAK CHECK FILE";err_chk
  fi

  if [ "$NAGRIB" = "nagrib2" ] ; then
    gpend
  fi

  if [ $SENDCOM = "YES" ] ; then
     cp $GEMGRD $COMOUT/.$GEMGRD
     mv $COMOUT/.$GEMGRD $COMOUT/$GEMGRD
     if [ $SENDDBN = "YES" ] ; then
         $DBNROOT/bin/dbn_alert MODEL ${DBN_ALERT_TYPE} $job $COMOUT/$GEMGRD
     else
       echo "##### DBN_ALERT_TYPE is: ${DBN_ALERT_TYPE} #####"
     fi
  fi

  let fhcnt=fhcnt+finc
done

#####################################################################
# GOOD RUN
set +x
echo "**************JOB $RUN NAWIPS COMPLETED NORMALLY ON THE IBM"
echo "**************JOB $RUN NAWIPS COMPLETED NORMALLY ON THE IBM"
echo "**************JOB $RUN NAWIPS COMPLETED NORMALLY ON THE IBM"
set -x
#####################################################################

msg='Job completed normally.'
echo $msg
postmsg "$jlogfile" "$msg"

############################### END OF SCRIPT #######################
