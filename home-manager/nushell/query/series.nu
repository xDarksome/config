use ../series.nu

use ../view_fs.nu 

export def main []: nothing -> list<record> {
 $env.VIEW_FS | view_fs query series
}
