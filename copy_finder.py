import shutil
src = r'C:\flutter_projects\BartenderApp\the_bar_bible\lib\screens\finder_screen.dart'
shutil.copy2(src, src + '.bak')
print('Backup done')
