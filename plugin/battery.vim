scriptencoding utf-8
" vim: set ts=8 sw=2 sts=2 :

if exists('loaded_battery')
  finish
endif
let loaded_battery = v:true

let UpdateBatteryInfoInterval = 10 * 1000    " 10 sec

let g:BatteryInfo = '? ---% [--:--:--]'

" 旧タイマの削除
if exists('TimerUbi')
  call timer_stop(TimerUbi)
endif

try
  python3 << EOF
from ctypes import windll
from ctypes import Structure, byref
from ctypes.wintypes import BYTE, LONG
import vim

class SystemPowerStatus(Structure):
  # https://msdn.microsoft.com/ja-jp/library/windows/desktop/aa373232(v=vs.85).aspx
  _fields_ = [
    ('ACLineStatus', BYTE),
    ('BatteryFlag', BYTE),
    ('BatteryLifePercent', BYTE),
    ('Reserved1', BYTE),
    ('BatteryLifeTime', LONG),
    ('BatteryFullLifeTime', LONG),
  ]

bat_info = { }
sps = SystemPowerStatus()

def bat_main():
  windll.kernel32.GetSystemPowerStatus(byref(sps))

  ac_line = sps.ACLineStatus
  charging = sps.BatteryFlag & 0x08
  status = '?' if ac_line == 255 else '$' if charging else '#' if ac_line == 1 else '@'
  bat_info['Status'] = status

  percent = sps.BatteryLifePercent
  bat_info['RemainingPercent'] = ('%3d' % percent if percent != -1 else '---') # + '%%'

  rem_sec = sps.BatteryLifeTime
  bat_info['RemainingTime'] = '[%2d:%02d:%02d]' % ( rem_sec / 3600, rem_sec % 3600 / 60, rem_sec % 60 ) if rem_sec != -1 else '[--:--:--]'

  full_sec = sps.BatteryFullLifeTime
  bat_info['FullTime'] = '[%2d:%02d:%02d]' % ( full_sec / 3600, full_sec % 3600 / 60, full_sec % 60 ) if full_sec != -1 else '[--:--:--]'

  # copy to vim var
  for i in bat_info:
    vim.command('let g:bat_info["' + i + '"] = "' + bat_info[i] + '"')
EOF

  function! UpdateBatteryInfo(dummy)
    call py3eval('bat_main()')
    let g:BatteryInfo = g:bat_info['Status'] . ' ' . g:bat_info['RemainingPercent'] . ' ' . g:bat_info['RemainingTime']
  endfunction

  let TimerUbi = timer_start(UpdateBatteryInfoInterval, 'UpdateBatteryInfo', {'repeat': -1})

  " Battery Information
  let bat_info = {}

  call UpdateBatteryInfo(0)
catch
endtry
