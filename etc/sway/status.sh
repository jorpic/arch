uptime=$(uptime | cut -d ',' -f1  | cut -d ' ' -f4,5)

battery=/sys/class/power_supply/BAT0
capacity=$(cat $battery/capacity)
if [[ "`cat $battery/status`" == 'Charging' ]] ; then
  power=⚡${capacity}%
else
  power=🌈${capacity}%
fi

wifi=$(iw dev | grep ssid)

date=$(date '+%a %F %T')

volume=$(amixer get Master | rg -om1 '\[.*\]' | sed 's/[^[:alnum:]]//g; s/on//; s/off/m/')

echo 🔉$volume $power 🌸$uptime 🔥$wifi 🗓$date 
