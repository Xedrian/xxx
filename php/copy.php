<?php
/**
 * @param string $sourceDir
 * @param string $targetDir
 */
function copyFiles($sourceDir, $targetDir)
{
	if (is_dir($sourceDir) && is_dir($targetDir)) {
		if ($dh = opendir($sourceDir)) {
			while (($fileName = readdir($dh)) !== false) {
				if (is_file($file = $sourceDir . $fileName)) {
					@unlink($targetDir . $fileName);
					@copy($file, $targetDir . $fileName);
				}
			}
			closedir($dh);
		}
	} else {
		if (!is_dir($sourceDir)) {
			echo "Source-Dir: '" . $sourceDir . "' is not a directory'\n";
		}
		if (!is_dir($targetDir)) {
			echo "Target-Dir: '" . $targetDir . "' is not a directory'\n";
		}
	}
}