<?php
/**
 * @param string $sourceDir
 * @param string $targetDir
 */
function copyFiles($sourceDir, $targetDir)
{
    var_dump($sourceDir, $targetDir);
    if ($dh = opendir($sourceDir)) {
        while (($fileName = readdir($dh)) !== false) {
            if (is_file($file = $sourceDir . $fileName)) {
                @unlink($targetDir . $fileName);
                @copy($file, $targetDir . $fileName);
            }
        }
        closedir($dh);
    }

}