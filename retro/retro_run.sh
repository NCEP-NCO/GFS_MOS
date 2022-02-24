#!/bin/sh
set -x

#dateList=20171130
dateList=`seq 20171210 1 20171231`
GFSDIR="/gpfs/hps2/ptmp/Geoff.Wagner/retro"
#GFSDIR="/gpfs/tp2/mdl/mdlens/noscrub/gmos/retro"
prevDate=20171130
prevCycle=12

for thisDate in $dateList; do
   for cycle in 00 12; do
      echo $thisDate$cycle
      let attempts=1
      while [[ $attempts -le 120 ]]
      do
         if [[ -f $GFSDIR/retro.$prevDate/mdl_gfsgmosco.t${prevCycle}z ]]; then
         #Orginally used station MOS file here, but switched to gridded to avoid stacking up jobs in LSF quicker than they can clear.
         #if [[ -f $GFSDIR/retro.$prevDate/mdl_gfsmos.t${prevCycle}z ]]; then
            echo "Gridded MOS file (short-range or more) found. Proceeding."
            /gpfs/hps3/mdl/mdlstat/noscrub/usr/Geoff.Wagner/mos-oper/gfs_mos/branches/gmos2017/run_gfsmos_master.sh.case.retro $thisDate$cycle
            prevDate=$thisDate
            prevCycle=$cycle
            break
         else
            if [[ $attempts -le 60 ]]; then
               sleep 120
            else
               sleep 300
            fi
            attempts=$((attempts+1))
         fi
      done
   done
done
