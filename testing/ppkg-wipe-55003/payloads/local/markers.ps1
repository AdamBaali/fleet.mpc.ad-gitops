# Lab only: user data that a reset must remove.
'lab data before wipe' | Set-Content C:\lab-marker.txt
New-Item -ItemType Directory C:\Users\lab1-data -Force | Out-Null
'x' | Set-Content C:\Users\lab1-data\marker.txt
'markers written'
